# Atividade - Automação de permissões e relatório diário em /shared

Aluno: Leonardo  


## O que tem aqui

| Arquivo | Para que serve |
|---|---|
| `manage_permissions.sh` | Cria o grupo e a pasta de um projeto em `/shared` e libera o acesso só para os usuários do projeto |
| `daily_report.sh` | Gera o relatório dos arquivos criados/modificados nas últimas 24h |
| `evidencias/` | Prints dos testes |

## Como configurar

Os dois scripts precisam rodar como root (ou com `sudo`), porque mexem com grupos, donos de pasta e escrevem em `/var`.

1. Copiar os scripts para a máquina (pode ser em `/opt/scripts`, por exemplo).
2. Dar permissão de execução:
   ```bash
   chmod +x manage_permissions.sh daily_report.sh
   ```
3. Não precisa criar `/shared` nem `/var/reports` na mão, os scripts criam se não existirem.

## Parte 1 - manage_permissions.sh

**Uso:**
```bash
sudo ./manage_permissions.sh <projeto> <usuarios>
```

**Exemplos:**
```bash
sudo ./manage_permissions.sh projeto_alpha "ana,bruno,carlos"
sudo ./manage_permissions.sh projeto_alpha "ana bruno carlos"
```
A lista de usuários vai entre aspas e pode ser separada por vírgula ou por espaço.

**O que o script faz, em ordem:**
1. Confere se está rodando como root e se recebeu os 2 argumentos.
2. Valida o nome do projeto (só letras, números, `_` e `-`), porque ele vira nome de grupo e de pasta.
3. Cria o grupo com o nome do projeto, se ainda não existir.
4. Cria `/shared/<projeto>`, se ainda não existir.
5. Para cada usuário da lista: se o usuário não existe no sistema, avisa e pula; se já está no grupo, avisa; senão adiciona com `usermod -aG`.
6. Deixa a pasta com dono `root`, grupo do projeto e permissão `2770`.
7. Mostra um resumo no final.

**Sobre a permissão 2770:**
- `7` para o dono (root) e `7` para o grupo: ler, criar e modificar arquivos.
- `0` para os outros: não conseguem nem listar a pasta.
- O `2` na frente é o *setgid*. Com ele, todo arquivo criado dentro da pasta fica com o grupo do projeto, e não com o grupo principal de quem criou. Sem isso os colegas de projeto não conseguiriam editar os arquivos uns dos outros.
- Se o `setfacl` estiver instalado, o script também define uma ACL padrão para os arquivos novos já saírem com escrita para o grupo (independente do umask do usuário).

**Robustez (o que ele trata):**
- Grupo ou pasta que já existem: não dá erro, só avisa e continua.
- Usuário que não existe: é ignorado e o script segue com os outros.
- Rodar o script de novo com o mesmo projeto não quebra nada.
- Argumentos faltando ou nome de projeto inválido: mostra o erro e sai.

**Observação:** quem já estava logado quando foi adicionado ao grupo precisa sair e entrar de novo (ou usar `newgrp <projeto>`) para o grupo valer na sessão.

## Parte 2 - daily_report.sh

**Uso:**
```bash
sudo ./daily_report.sh
```

**O que o script faz:**
1. Confere se `/shared` existe e cria `/var/reports` se precisar.
2. Usa o `find` com `-type f -mmin -1440` para pegar os arquivos modificados nas últimas 24 horas (arquivo recém-criado também tem data de modificação recente, então entra no mesmo filtro).
3. Para cada arquivo, descobre o projeto pela primeira pasta depois de `/shared`.
4. Salva tudo em `/var/reports/report_YYYY-MM-DD.txt` com a data do dia.

**Formato de cada linha do relatório:**
```
Projeto: projeto_alpha | Arquivo: /shared/projeto_alpha/plano.txt
```
Arquivos que estão soltos direto em `/shared` aparecem como `(sem projeto)`. No final tem o total de arquivos.

**Detalhes:**
- Usa `-print0` e `read -d ''` para funcionar com nomes de arquivo que têm espaço.
- Só faz uma passada no `find`, sem ficar chamando comando externo para cada arquivo (mais leve).
- Se rodar duas vezes no mesmo dia, o relatório do dia é sobrescrito.

### Agendando para rodar todo dia (cron)

Para gerar o relatório automaticamente todo dia às 23:00:
```bash
sudo crontab -e
```
e adicionar a linha:
```
0 23 * * * /opt/scripts/daily_report.sh >> /var/log/daily_report.log 2>&1
```

## Como testar

O passo a passo que usei para os prints está em `evidencias/roteiro_testes.md`.

## Limitações

- O script só adiciona usuários ao grupo, não remove. Para tirar alguém do projeto precisa usar `gpasswd -d usuario projeto`.
- O relatório usa a data de modificação (mtime), então um arquivo só *movido* para dentro de `/shared` pode não aparecer.
