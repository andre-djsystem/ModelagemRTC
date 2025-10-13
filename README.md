# Reforma Tributária (LC 214/2025) — Modelagem de dados para determinar o **cClassTrib** automaticamente

> “Simplificar é a forma mais sofisticada de resolver problemas.”

Este repositório traz um **pacote completo** (DDL, cargas, funções e exemplos) para resolver o **cClassTrib** de forma **automática** na emissão de documentos fiscais (NF-e, NFC-e e correlatos), tomando como base a **Lei Complementar nº 214/2025** e seus **Anexos/Artigos**.

A solução está orientada a **dados**: você carrega as tabelas e usa a procedure `RESOLVE_CCLASSTRIB` para obter, de forma hierárquica, o código correto conforme **tipo de operação**, **produto**, **Regra RTC (Anexo/Artigo)**, **vigência** e **modelo de documento**.

---

## 🚀 Como começar

1) **Crie o esquema** (tabelas + funções/procedures):  
   Arquivo: `tabelas.sql` (inclui `CCLASSTRIB_OFICIAL`, `TOP`, `PRODUTO`, `TOP_PRODUTO`, `NCM_CCLASSTRIB`, `VALIDA_VIGENCIA`, `VALIDA_MODELO`, `VALIDA_CCLASSTRIB`, `RESOLVE_CCLASSTRIB` e `CCLASSTRIB_POR_NCM`).

2) **Carregue a tabela oficial** de códigos e descrições:  
   Arquivo: `CCLASSTRIB_OFICIAL.sql` (espelho de códigos oficiais: descrição, CST, percentuais, vigência, indicadores por modelo).

3) **Carregue o mapeamento NCM ⇄ Regra RTC ⇄ cClassTrib**:  
   Arquivo: `ncm_cclasstrib.sql` (somente `INSERT`s). Regras de composição de `REGRA_RTC`:
   - `ANEXO_{n}` quando há **apenas uma** possibilidade para o NCM;
   - `ANEXO_{n}_ART_{xxx}` quando o **mesmo NCM** aparece em **múltiplos anexos/artigos**;
   - `ANEXO_{n}_ART_{xxx}_{CCLASSTRIB}` quando, **dentro do mesmo (anexo, artigo)**, há **mais de um cClassTrib** com aplicações distintas (preserva todas as hipóteses);
   - Exceções **por artigo** (sem anexo) incluem, por exemplo, `('96190000','ART_147','200013')`.

4) **Cargas de exemplo** (TOP/PRODUTO/TOP_PRODUTO) e **consultas de teste**:  
   Arquivos: `dados-exemplo.sql` e `comandos.sql`. Estes populam casos didáticos (pão — Anexo I; fertilizantes — Anexo IX; saúde menstrual — Art. 147; etc.) e trazem *queries* prontas para explorar a solução.

---

## 🗂️ Estrutura e relacionamento entre tabelas

- **`CCLASSTRIB_OFICIAL`**: tabela **oficial** com descrição, CST, percentuais (`PREDIBS/PREDCBS`), vigência e *flags* por modelo (NFe/NFCe).  
- **`TOP`**: tipo de operação (venda, devolução, bonificação, transferência…). Pode conter **cClassTrib fixo** (se preenchido, tem prioridade).  
- **`TOP_PRODUTO`**: exceção por **operação+produto** (ex.: benefício para produtor rural em operação específica).  
- **`PRODUTO`**: amarra o **NCM** ao **`REGRA_RTC`** do item (ex.: `ANEXO_1`, `ANEXO_9`, `ART_147`), permite informar um cClasstrib em caso de exceções.  
- **`PARTICIPANTE`**: tipo de participante da operação (pessoa física, pessoa jurídica, órgão público, etc). 
- **`NCM_CCLASSTRIB`**: **fallback**: mapeia **(NCM, REGRA_RTC)** para `CCLASSTRIB` (com colunas **ANEXO** e **ARTIGO** para busca). Mantém **todas** as aplicações distintas usando a convenção textual de `REGRA_RTC` descrita acima.

---

## ⚙️ Como o motor de resolução funciona

A procedure **`RESOLVE_CCLASSTRIB`** recebe `(ID_TOP, ID_PRODUTO, DATA_EMISSAO, MODELO_DF, ID_PARTICIPANTE)` e retorna:

- `R_CCLASSTRIB`, `R_CST`, `R_FONTE` (TOP / TOP_PRODUTO / PRODUTO / NCM / NCM_PARTICIPANTE, NBS / NBS_PARTICIPANTE), `R_PREDIBS`, `R_PREDCBS`.

**Ordem de prioridade**:
1. **TOP**: se o `TOP.CCLASSTRIB` vier preenchido, ele **vence**.  
2. **TOP_PRODUTO**: senão, tenta a exceção por operação+produto.  
3. **PRODUTO**: senão, tenta a exceção do produto.  
4. **NCM_CCLASSTRIB**: busca por `(PRODUTO.NCM, PRODUTO.REGRA_RTC, ID_PARTICIPANTE)`. 
5. **NCM_CCLASSTRIB**: por fim, busca pelo par `(PRODUTO.NCM, PRODUTO.REGRA_RTC)` no fallback.

Em cada candidato, a procedure valida **vigência** (`VALIDA_VIGENCIA`) e **modelo** (`VALIDA_MODELO`). Se não houver nenhum válido, retorna `NULL` e o app pode aplicar `000001` (integral) ou tratar a exceção.

> Exemplos (vide `comandos.sql`):
>
> ```sql
> SELECT * FROM RESOLVE_CCLASSTRIB(1, 101, DATE '2026-02-01', 'NFe', 0);   -- pão (Anexo I)
> SELECT * FROM RESOLVE_CCLASSTRIB(1, 201, DATE '2026-02-01', 'NFe', 0);   -- fertilizante (Anexo IX)
> SELECT * FROM RESOLVE_CCLASSTRIB(2, 201, DATE '2026-02-01', 'NFe', 0);   -- produtor rural (TOP_PRODUTO)
> SELECT * FROM RESOLVE_CCLASSTRIB(1, 401, DATE '2026-02-01', 'NFe', 0);   -- saúde menstrual (ART_147)
> ```

---

## 🧩 Regras importantes de modelagem

- **`REGRA_RTC` textual com granularidade suficiente**  
  - Evitamos perder aplicações diferentes em um mesmo NCM:  
    - `ANEXO_11_ART_142_200043` **≠** `ANEXO_11_ART_142_200044` (caso *segurança/soberania nacional*, comprador e requisitos societários distintos).  
  - Para NCM **único** em um único anexo, mantemos **`ANEXO_n`** simples, sem inflar com artigo.
- **Colunas `ANEXO` e `ARTIGO` (INTEGER)**  
  - Facilitam buscas e *reporting* sem “parsear” a string.  
  - Exemplos de *queries*:  
    - Por anexo: `WHERE ANEXO = 9` ou `REGRA_RTC LIKE 'ANEXO_9%'`  
    - Por artigo: `WHERE ARTIGO = 147` ou `REGRA_RTC LIKE '%_ART_147%'`
- **Tabela Oficial** (`CCLASSTRIB_OFICIAL`)  
  - Centraliza vigência, CST e percentuais. Toda resolução **consulta** essa tabela.

---

## 🔎 Exemplos práticos (do **Banco de Dados de Exemplo**)

> *Estes exemplos estão prontos para execução após as cargas de `dados-exemplo.sql` e `comandos.sql`.*

- **Pão (Anexo I)**:  
  `SELECT * FROM RESOLVE_CCLASSTRIB(1, 101, DATE '2026-02-01', 'NFe', null);`  
  → fonte: **NCM** (*fallback*), retorna `200003` (redução 100%).

- **Fertilizante (Anexo IX)** — venda comum vs. produtor rural:  
  - Comum: `RESOLVE_CCLASSTRIB(1, 201, ...)` → **NCM** (Anexo IX).  
  - Produtor rural: `RESOLVE_CCLASSTRIB(2, 201, ...)` → **TOP_PRODUTO** (exceção `515001`).

- **Saúde menstrual (Art. 147)**:  
  `SELECT * FROM RESOLVE_CCLASSTRIB(1, 401, DATE '2026-02-01', 'NFe', null);`  
  → **ART_147** (NCM `96190000`) com `200013` (alíquota zero).

- **Consulta por NCM**:  
  `SELECT * FROM CCLASSTRIB_POR_NCM('94029090', null);`  
  → Lista todas as aplicações mapeadas para o NCM (útil para auditoria).

---

## 📂 Estrutura dos arquivos do repositório

- `tabelas.sql` — DDL completo do esquema + funções/procedures.  
- `CCLASSTRIB_OFICIAL.sql` — carga do catálogo oficial (códigos, descrições, vigência, *flags*).  
- `ncm_cclasstrib.sql` — carga de `NCM_CCLASSTRIB` (apenas `INSERT`s).  
- `dados-exemplo.sql` — dados de exemplo para `TOP`, `PRODUTO`, `TOP_PRODUTO`.  
- `comandos.sql` — consultas de demonstração (*how-to*) para explorar a solução.

---

## ✅ Benefícios

- **Zero decisão manual** no momento da emissão: tudo orientado por dados.  
- **Priorização clara**: TOP → TOP_PRODUTO → NCM_CCLASSTRIB.  
- **Compatibilidade legal**: vigência e modelo verificados a cada candidato.  
- **Flexível e audível**: todas as hipóteses ficam **mapeadas** (inclusive múltiplas aplicações por NCM).  
- **Portável**: implementado em **Firebird**, mas adaptável a qualquer SGBD relacional.

---

## 📄 Licença

Este conteúdo é fornecido “como está”, com foco didático e para acelerar implementações. Ajustes e evoluções são bem-vindos via *pull requests*.