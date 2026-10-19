#!/bin/bash
# ------------------------------------------------------------
# manage_permissions.sh
# Cria o grupo e o diretório de um projeto dentro de /shared,
# adiciona os usuários no grupo e ajusta as permissões.
#
# Uso:    sudo ./manage_permissions.sh <projeto> <usuarios>
# Exemplo: sudo ./manage_permissions.sh projeto_alpha "ana,bruno,carlos"
#          (os usuários podem ser separados por vírgula ou espaço)
# ------------------------------------------------------------

BASE_DIR="/shared"

# --- função para mostrar como usar o script ---
uso() {
    echo "Uso: sudo $0 <nome_do_projeto> <lista_de_usuarios>"
    echo "Exemplo: sudo $0 projeto_alpha \"ana,bruno,carlos\""
}

# --- 1. validações iniciais ---

# precisa ser root, senão groupadd/usermod/chown não funcionam
if [ "$EUID" -ne 0 ]; then
    echo "Erro: execute o script como root (use sudo)." >&2
    exit 1
fi

# precisa de exatamente 2 argumentos
if [ "$#" -ne 2 ]; then
    echo "Erro: número de argumentos inválido." >&2
    uso
    exit 1
fi

PROJETO="$1"
# troca vírgula por espaço, assim aceita "ana,bruno" e "ana bruno"
USUARIOS="${2//,/ }"

# o nome do projeto vai virar nome de grupo e de pasta, então
# só deixo letras, números, _ e -  (evita coisas como "../" ou espaços)
if ! [[ "$PROJETO" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "Erro: nome de projeto inválido '$PROJETO'." >&2
    echo "Use apenas letras, números, '_' ou '-'." >&2
    exit 1
fi

DIR_PROJETO="$BASE_DIR/$PROJETO"

# --- 2. cria o diretório base /shared (se não existir) ---
if [ ! -d "$BASE_DIR" ]; then
    mkdir -p "$BASE_DIR" || { echo "Erro ao criar $BASE_DIR" >&2; exit 1; }
    chmod 755 "$BASE_DIR"
    echo "Diretório base $BASE_DIR criado."
fi

# --- 3. cria o grupo (se não existir) ---
if getent group "$PROJETO" > /dev/null; then
    echo "Grupo '$PROJETO' já existe, vou usar ele."
else
    if groupadd "$PROJETO"; then
        echo "Grupo '$PROJETO' criado."
    else
        echo "Erro ao criar o grupo '$PROJETO'." >&2
        exit 1
    fi
fi

# --- 4. cria o diretório do projeto (se não existir) ---
if [ -d "$DIR_PROJETO" ]; then
    echo "Diretório '$DIR_PROJETO' já existe."
else
    if mkdir "$DIR_PROJETO"; then
        echo "Diretório '$DIR_PROJETO' criado."
    else
        echo "Erro ao criar o diretório '$DIR_PROJETO'." >&2
        exit 1
    fi
fi

# --- 5. adiciona os usuários no grupo ---
ADICIONADOS=0
IGNORADOS=0

for usuario in $USUARIOS; do
    # confere se o usuário existe no sistema
    if ! id "$usuario" > /dev/null 2>&1; then
        echo "Aviso: usuário '$usuario' não existe, ignorando."
        IGNORADOS=$((IGNORADOS + 1))
        continue
    fi

    # confere se já faz parte do grupo
    if id -nG "$usuario" | tr ' ' '\n' | grep -qx "$PROJETO"; then
        echo "Usuário '$usuario' já está no grupo '$PROJETO'."
        continue
    fi

    if usermod -aG "$PROJETO" "$usuario"; then
        echo "Usuário '$usuario' adicionado ao grupo '$PROJETO'."
        ADICIONADOS=$((ADICIONADOS + 1))
    else
        echo "Aviso: não consegui adicionar '$usuario' ao grupo." >&2
        IGNORADOS=$((IGNORADOS + 1))
    fi
done

# --- 6. ajusta dono e permissões do diretório ---
# dono = root, grupo = grupo do projeto
chown root:"$PROJETO" "$DIR_PROJETO" || { echo "Erro no chown." >&2; exit 1; }

# 2770 = rwx para dono e grupo, nada para os outros
# o "2" (setgid) faz os arquivos novos herdarem o grupo do projeto
chmod 2770 "$DIR_PROJETO" || { echo "Erro no chmod." >&2; exit 1; }

# (opcional) se tiver o setfacl instalado, deixa os arquivos novos
# já com permissão de escrita para o grupo, independente do umask
if command -v setfacl > /dev/null 2>&1; then
    setfacl -d -m g::rwx "$DIR_PROJETO" 2>/dev/null
fi

# --- 7. resumo final ---
echo "-------------------------------------------"
echo "Projeto: $PROJETO"
echo "Diretório: $DIR_PROJETO"
echo "Usuários adicionados: $ADICIONADOS | ignorados: $IGNORADOS"
ls -ld "$DIR_PROJETO"
echo "Obs: usuário que já estava logado precisa sair e entrar de novo"
echo "     para o novo grupo valer na sessão dele."
exit 0
