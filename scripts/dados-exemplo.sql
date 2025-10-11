/* =========================
   6) CARGAS DE EXEMPLO
   ========================= */

/* TOPs típicos */
DELETE FROM TOP;
INSERT INTO TOP (ID_TOP, DESCRICAO, CCLASSTRIB) VALUES (1, 'Venda', NULL);
INSERT INTO TOP (ID_TOP, DESCRICAO, CCLASSTRIB) VALUES (2, 'Venda Produtor Rural', NULL);
INSERT INTO TOP (ID_TOP, DESCRICAO, CCLASSTRIB) VALUES (3, 'Transferência entre Filiais', '410999');
INSERT INTO TOP (ID_TOP, DESCRICAO, CCLASSTRIB) VALUES (4, 'Devolução de Venda', NULL);
INSERT INTO TOP (ID_TOP, DESCRICAO, CCLASSTRIB) VALUES (5, 'Bonificação (não onerosa)', '410999');
INSERT INTO TOP (ID_TOP, DESCRICAO, CCLASSTRIB) VALUES (6, 'Demonstração/Mostruário', '410999');

/* Produtos de exemplo */
DELETE FROM PRODUTO;

-- ANEXO I (pão + pré-mistura)
INSERT INTO PRODUTO (ID_PRODUTO, DESCRICAO, NCM, REGRA_RTC)
VALUES (101, 'Pão francês 50g', '19059090', 'ANEXO_1');

INSERT INTO PRODUTO (ID_PRODUTO, DESCRICAO, NCM, REGRA_RTC)
VALUES (102, 'Pré-mistura para pão francês', '19012010', 'ANEXO_1');

-- ANEXO IX (fertilizantes válidos para o Anexo IX)
INSERT INTO PRODUTO (ID_PRODUTO, DESCRICAO, NCM, REGRA_RTC)
VALUES (201, 'Fertilizante especial', '38249979', 'ANEXO_9');

INSERT INTO PRODUTO (ID_PRODUTO, DESCRICAO, NCM, REGRA_RTC)
VALUES (202, 'Fertilizante especial', '38249977', 'ANEXO_9');

-- ART_147 (saúde menstrual) — NCM 9619.00.00 dentro do artigo 147
INSERT INTO PRODUTO (ID_PRODUTO, DESCRICAO, NCM, REGRA_RTC)
VALUES (401, 'Absorvente higiênico externo', '96190000', 'ART_147');

INSERT INTO PRODUTO (ID_PRODUTO, DESCRICAO, NCM, REGRA_RTC)
VALUES (402, 'Fralda', '96190000', '');

-- Tributação integral (exemplo fora de benefícios)
INSERT INTO PRODUTO (ID_PRODUTO, DESCRICAO, NCM, REGRA_RTC)
VALUES (301, 'Camiseta algodão', '61091000', '');


/* Regras específicas de exemplo */
DELETE FROM TOP_PRODUTO;

-- Venda p/ Produtor Rural (diferimento) — mesma mercadoria do Anexo IX
INSERT INTO TOP_PRODUTO (ID_TOP, ID_PRODUTO, CCLASSTRIB)
VALUES (2, 201, '515001');

INSERT INTO TOP_PRODUTO (ID_TOP, ID_PRODUTO, CCLASSTRIB)
VALUES (2, 202, '515001');
COMMIT;



COMMIT;

/* =========================
   7) Dicas de uso
   =========================
-- Pão (ANEXO I)
SELECT * FROM RESOLVE_CCLASSTRIB(1, 101, DATE '2026-02-01', 'NFe');  -- fonte: NCM (ANEXO_I)

-- Fertilizante (ANEXO IX), venda comum
SELECT * FROM RESOLVE_CCLASSTRIB(1, 201, DATE '2026-02-01', 'NFe');  -- fonte: NCM (ANEXO_IX)

-- Fertilizante (ANEXO IX), venda produtor rural (diferimento)
SELECT * FROM RESOLVE_CCLASSTRIB(2, 201, DATE '2026-02-01', 'NFe');  -- fonte: TOP_PRODUTO

-- Saúde menstrual (ART_147), mesmo NCM 9619.00.00 mas com REGRA_RTC='ART_147'
SELECT * FROM RESOLVE_CCLASSTRIB(1, 401, DATE '2026-02-01', 'NFe');  -- fonte: NCM (ART_147)

-- NCM sem benefício e com “padrão integral”
SELECT * FROM RESOLVE_CCLASSTRIB(1, 301, DATE '2026-02-01', 'NFe');  -- fonte: NCM ('' → 000001)


   Se R_CCLASSTRIB vier NULL:
     - aplique '000001' no app, ou
     - lance uma exception de classificação conforme sua política.
*/
