# Prompt – Atualização de `NCM_NBS_CCLASSTRIB` a partir dos anexos

## Contexto e entradas

Você recebeu dois arquivos anexados:

- `dadosOriginais.txt` contendo `var dadosOriginais = [...]` com a estrutura oficial usada para montar as regras e anexos.
- `ncm_cclasstrib.sql` contendo o estado atual dos INSERTs que já estão em produção.

## Objetivo

Gerar um *pacote de saída* com:

1) **`ncm_nbs_cclasstrib_inserts.sql`** — INSERTs completos no layout **NCM_NBS_CCLASSTRIB**, ordenados e **sem duplicatas**.  
2) **`ncm_nbs_cclasstrib_delta.sql`** — *apenas as diferenças* (ADICIONAR/REMOVER/ALTERAR) **entre o que foi reconstruído a partir do `dadosOriginais` e o que existe hoje no `ncm_cclasstrib.sql`**.  
3) **`ncm_nbs_cclasstrib_auditoria.csv`** — CSV auxiliar com colunas: `NCM_NBS;TIPO;ANEXO;ARTIGO;REGRA_RTC;CCLASSTRIB`.  
4) **`ncm_nbs_cclasstrib_diff_report.txt`** — relatório humano de diffs, incluindo validações pedidas abaixo.

> **Regra de ouro:** **só** gere deltas (arquivos 2 e 4 com conteúdo “não vazio”) se o `dadosOriginais` resultar em mudanças **reais** face ao `ncm_cclasstrib.sql`. Se não houver mudanças, gere `ncm_nbs_cclasstrib_delta.sql` com apenas um comentário `-- SEM MUDANÇAS` e o relatório com contagens zeradas.

---

## Esquema de destino (definitivo)

```sql
CREATE TABLE NCM_NBS_CCLASSTRIB (
  NCM_NBS         VARCHAR(10) NOT NULL,
  REGRA_RTC       VARCHAR(50) NOT NULL,
  ID_PARTICIPANTE INTEGER DEFAULT 0 NOT NULL,
  TIPO            VARCHAR(5) NOT NULL,
  CCLASSTRIB      VARCHAR(7)  NOT NULL REFERENCES CCLASSTRIB_OFICIAL(CCLASSTRIB),
  ANEXO           INTEGER,
  ARTIGO          INTEGER,
  CONSTRAINT PK_NCM_NBS_CCLASSTRIB PRIMARY KEY (NCM_NBS, REGRA_RTC, ID_PARTICIPANTE),
  CONSTRAINT FK_NCM_NBS_CCT_PART FOREIGN KEY (ID_PARTICIPANTE) REFERENCES TIPO_PARTICIPANTE (ID_PARTICIPANTE)
);
```

> Nos INSERTs gerados a partir do dadosOriginais, use sempre ID_PARTICIPANTE = 0. Linhas com ID_PARTICIPANTE <> 0 são inclusões manuais e não devem ser removidas/alteradas automaticamente..

---

## Regras de extração a partir de `dadosOriginais`

Para cada elemento em `dadosOriginais[*].ClassificacoesTributarias[*].Anexos[*]`:

- **NCM_NBS**: use `Anexos[*].CodNcmNbs`, **preservando exatamente os dígitos originais** (apenas remova pontuação/espaços). *Não* padronize para 8 dígitos; mantenha NCM=8, NBS=7, etc.
- **TIPO**: derive de `TipoAnexo`: `1 → 'NCM'`, `2 → 'NBS'`. (Se excepcionalmente ausente, *fallback* opcional por comprimento: 7→NBS; caso contrário→NCM.)
- **ANEXO**: `Anexos[*].NroAnexo`; se ausente, `ClassificacaoTributaria.NroAnexo`; se ausente → `NULL`.
- **ARTIGO**: extraia o número após `#art` em `TexUrlLegislacao`; se não existir → `NULL`.
- **CCLASSTRIB**: literal de `CodClassTrib` (string).
- **ID_PARTICIPANTE**: `0` (fixo).

---

## Regras determinísticas de **REGRA_RTC**

Agrupe por `(NCM_NBS, TIPO)` e avalie as combinações distintas `(ANEXO, ARTIGO, CCLASSTRIB)`.

1. **Caso único** (apenas 1 combinação):  
   - Se houver **ANEXO** → `ANEXO_{n}`.  
   - Senão, se houver **ARTIGO** → `ART_{xxx}`.  
   - Senão, vazio → ``.  
   **Observação**: a simples presença de ARTIGO **não** acrescenta `_ART_` se não for necessária para distinguir hipóteses.

2. **Múltiplas hipóteses**:
   - **Mais de um CCLASSTRIB no mesmo (ANEXO, ARTIGO)** →  
     • com artigo: `ANEXO_{n}_ART_{xxx}_{CCLASSTRIB}`  
     • sem artigo: `ANEXO_{n}_{CCLASSTRIB}`
   - **Diferença por ANEXO** (artigos iguais ou não relevantes para distinguir) → `ANEXO_{n}` (sem `_ART_`).
   - **Dentro de um mesmo ANEXO, múltiplos ARTIGOS distintos** → `ANEXO_{n}_ART_{xxx}` (aqui o `_ART_` é **obrigatório** porque distingue hipóteses dentro do anexo).  
   - **Sem ANEXO mas múltiplos ARTIGOS** → `ART_{xxx}`.

3. **Sufixo `_ART_`** só aparece quando o artigo é necessário para distinguir hipóteses **dentro do mesmo ANEXO** (ou quando não há ANEXO e o artigo distingue hipóteses).

**Exceção obrigatória**  
Garanta que exista a linha (se ainda não estiver presente nas saídas reconstruídas):

```sql
INSERT INTO NCM_NBS_CCLASSTRIB (NCM_NBS, REGRA_RTC, ID_PARTICIPANTE, TIPO, CCLASSTRIB, ANEXO, ARTIGO) VALUES ('96190000', 'ART_147', 0, 'NCM', '200013', NULL, 147);
```

---

## Geração dos arquivos

### 1) `ncm_nbs_cclasstrib_inserts.sql`
Gere **apenas INSERTs** no formato, em apenas uma linha:

```sql
INSERT INTO NCM_NBS_CCLASSTRIB(NCM_NBS, REGRA_RTC, ID_PARTICIPANTE, TIPO, CCLASSTRIB, ANEXO, ARTIGO) VALUES ('{NCM_NBS}', '{REGRA_RTC}', 0, '{TIPO}', '{CCLASSTRIB}', {ANEXO|NULL}, {ARTIGO|NULL});
```

- **Ordenação**: por `(NCM_NBS, REGRA_RTC, TIPO, CCLASSTRIB)`.
- **Deduplicação**: elimine duplicatas exatas por `(NCM_NBS, TIPO, REGRA_RTC, CCLASSTRIB, ANEXO, ARTIGO, ID_PARTICIPANTE)`.
- **Coerência**: se um `ANEXO` tiver múltiplos `ARTIGO`, use `ANEXO_{n}_ART_{xxx}`; se tiver um só artigo, **não** adicione `_ART_`.

### 2) `ncm_nbs_cclasstrib_auditoria.csv`
- Colunas: `NCM_NBS;TIPO;ANEXO;ARTIGO;REGRA_RTC;CCLASSTRIB`.
- Um registro por INSERT gerado (após deduplicação), na mesma ordem.

---

## Diff inteligente contra `ncm_cclasstrib.sql`

O arquivo de entrada pode estar no **layout antigo** (`NCM_CCLASSTRIB`) ou no **layout novo** (`NCM_NBS_CCLASSTRIB`).

1. **Parse do arquivo de entrada**  
   - Detecte automaticamente o layout (pela *target table* e ordem das colunas).  
   - Projete tudo para o **layout canônico** `(NCM_NBS, TIPO, REGRA_RTC, CCLASSTRIB, ANEXO, ARTIGO, ID_PARTICIPANTE)`.  
     - Se vier sem `TIPO`, derive via: 7 dígitos → `NBS`; caso contrário → `NCM`.  
     - Se não houver `ID_PARTICIPANTE`, considere `0`.  
   - Normalize `NCM_NBS` só removendo pontuação (não mude o número de dígitos).
   - Compare e gere deltas exclusivamente somente sobre linhas com ID_PARTICIPANTE = 0
   - Nunca classifique como REMOVIDAS ou ALTERADAS as linhas do conjunto manual (ID_PARTICIPANTE <> 0). Elas não entram no diff.

2. **Compare conjuntos**  
   - **ADICIONADAS**: presentes no **reconstruído** e ausentes no arquivo de entrada (após projeção).  
   - **REMOVIDAS**: presentes no arquivo de entrada e ausentes no reconstruído.  
   - **ALTERADAS**: mesma *chave fraca* `(NCM_NBS, TIPO, CCLASSTRIB, ANEXO, ARTIGO)` porém `REGRA_RTC` diferente **ou** diferença de `ANEXO/ARTIGO`.  
   - Use comparação *case-sensitive* para `REGRA_RTC` e `CCLASSTRIB`.

3. **`ncm_nbs_cclasstrib_delta.sql`**  
   - Não remova linhas com a REGRA_RTC = `ART_9` pois foram adicionadas manualmente.
   - Para cada **REMOVIDA**: `DELETE` por chave primária `(NCM_NBS, REGRA_RTC, ID_PARTICIPANTE=0)`.  
   - Para cada **ALTERADA**: `DELETE` da versão antiga **e** `INSERT` da versão nova.  
   - Para cada **ADICIONADA**: apenas `INSERT`.  
   - Linhas com ID_PARTICIPANTE <> 0 (manuais): nunca produzir DELETE/INSERT. Ignorar no cálculo de diferenças (preservar no banco).
   - Ordene por `(NCM_NBS, REGRA_RTC, TIPO, CCLASSTRIB)`.  
   - Se **não houver diferenças**, escreva apenas: `-- SEM MUDANÇAS`.

4. **`ncm_nbs_cclasstrib_diff_report.txt`**  
   - Totais: `+ adicionadas`, `- removidas`, `~ alteradas`.  
   - Top 10 exemplos de cada tipo (uma linha por exemplo).  
   - Contagem de NCM/NBS **normalizados sem `_ART_` indevido** (casos únicos).  
   - Confirmação explícita da inclusão do caso **96190000 / ART_147**.  
   - Observação se houve **deduplicação** (quantas linhas idênticas foram colapsadas).

---

## Validações obrigatórias

- **Sem duplicatas** exatas nos INSERTs finais.  
- **Regra `_ART_`** só quando necessária para distinguir hipóteses **dentro do mesmo ANEXO** (ou na ausência de ANEXO).  
- **Caso 96190000 / ART_147** presente.  
- **TIPO** vindo de `TipoAnexo` (`1=NCM`, `2=NBS`) quando disponível.  
- `ncm_nbs_cclasstrib_delta.sql` vazio (comentado) **se nada mudou**.

---

## Formato de saída

Entregue **quatro** arquivos:

- `ncm_nbs_cclasstrib_inserts.sql`
- `ncm_nbs_cclasstrib_delta.sql`
- `ncm_nbs_cclasstrib_auditoria.csv`
- `ncm_nbs_cclasstrib_diff_report.txt`

E exiba, no corpo da resposta, um **resumo**: totais de adicionadas/removidas/alteradas, exemplos (até 10), contagem de normalizações sem `_ART_` indevido, e a confirmação da exceção `96190000/ART_147`.

---

## Observações finais

- **Idempotência**: se rodar o processo duas vezes sem alteração no `dadosOriginais`, o **delta** deve continuar vazio.  
- **Robustez de parse**: o `dadosOriginais.txt` pode vir como `var dadosOriginais = […] ;` — trate a remoção do prefixo/sufixo ao fazer o parse.  
- Se o arquivo de entrada contiver INSERTs de outra tabela/ordem de colunas, ajuste automaticamente a projeção para o layout canônico antes de comparar.
