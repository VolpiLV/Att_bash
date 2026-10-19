#!/bin/bash
# ------------------------------------------------------------
# daily_report.sh
# Gera um relatório com os arquivos de /shared criados ou
# modificados nas últimas 24 horas.
# O relatório é salvo em /var/reports/report_YYYY-MM-DD.txt
#
# Uso: sudo ./daily_report.sh
# ------------------------------------------------------------

BASE_DIR="/shared"
REPORT_DIR="/var/reports"
DATA=$(date +%Y-%m-%d)
RELATORIO="$REPORT_DIR/report_$DATA.txt"

# --- validações ---
if [ ! -d "$BASE_DIR" ]; then
    echo "Erro: o diretório $BASE_DIR não existe." >&2
    exit 1
fi

# cria a pasta dos relatórios se ainda não existir
if [ ! -d "$REPORT_DIR" ]; then
    mkdir -p "$REPORT_DIR" || { echo "Erro ao criar $REPORT_DIR (rode com sudo?)" >&2; exit 1; }
fi

if [ ! -w "$REPORT_DIR" ]; then
    echo "Erro: sem permissão de escrita em $REPORT_DIR." >&2
    exit 1
fi

# --- cabeçalho do relatório ---
{
    echo "=========================================="
    echo " Relatório diário de arquivos - /shared"
    echo " Gerado em: $(date '+%d/%m/%Y %H:%M:%S')"
    echo " Período: últimas 24 horas"
    echo "=========================================="
    echo
} > "$RELATORIO"

TOTAL=0

# --- busca os arquivos ---
# -type f      -> só arquivos (não lista as pastas)
# -mmin -1440  -> modificados nos últimos 1440 min (= 24h)
#                 arquivo recém criado também tem mtime recente,
#                 então pega criados e modificados
# -print0 / read -d '' -> aguenta nome de arquivo com espaço
while IFS= read -r -d '' arquivo; do
    # tira o "/shared/" do começo do caminho
    relativo="${arquivo#"$BASE_DIR"/}"

    # o projeto é a primeira pasta depois de /shared
    if [[ "$relativo" == */* ]]; then
        projeto="${relativo%%/*}"
    else
        # arquivo solto direto em /shared, sem projeto
        projeto="(sem projeto)"
    fi

    echo "Projeto: $projeto | Arquivo: $arquivo" >> "$RELATORIO"
    TOTAL=$((TOTAL + 1))
done < <(find "$BASE_DIR" -type f -mmin -1440 -print0 2>/dev/null | sort -z)

# --- rodapé ---
{
    echo
    echo "------------------------------------------"
    echo "Total de arquivos: $TOTAL"
} >> "$RELATORIO"

if [ "$TOTAL" -eq 0 ]; then
    echo "Nenhum arquivo criado ou modificado nas últimas 24 horas." >> "$RELATORIO"
fi

echo "Relatório gerado: $RELATORIO ($TOTAL arquivo(s))"
exit 0
