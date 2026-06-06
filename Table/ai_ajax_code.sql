
DECLARE
    l_raw      CLOB;
    l_sql      CLOB;
    l_start    NUMBER;
    l_cursor   NUMBER;
    l_col_cnt  NUMBER;
    l_desc     DBMS_SQL.DESC_TAB;
    l_val      VARCHAR2(4000);
    l_cols     CLOB := '';
    l_rows     CLOB := '';
    l_row_cnt  NUMBER := 0;
    l_json     CLOB;
    l_schema   CLOB := '';
    l_prev_tbl VARCHAR2(200) := '';

    FUNCTION escape_json(p_str IN VARCHAR2) RETURN VARCHAR2 IS
        l_result VARCHAR2(4000);
    BEGIN
        l_result := p_str;
        l_result := REPLACE(l_result, '\',   '\\');
        l_result := REPLACE(l_result, '"',   '\"');
        l_result := REPLACE(l_result, CHR(10), '\n');
        l_result := REPLACE(l_result, CHR(13), '\r');
        l_result := REPLACE(l_result, CHR(9),  '\t');
        RETURN l_result;
    END;

BEGIN
   
    IF apex_application.g_x01 IS NULL OR TRIM(apex_application.g_x01) IS NULL THEN
        HTP.P('{"error":"Prompt is empty."}');
        RETURN;
    END IF;

   
    FOR rec IN (
        SELECT
            c.table_name,
            c.column_name,
            c.data_type,
            cm.comments AS col_comment,
            tc.comments AS tbl_comment,
            CASE
                WHEN cc.constraint_type = 'P' THEN 'PK'
                WHEN cc.constraint_type = 'R' THEN 'FK->' ||
                    (SELECT ac2.table_name || '.' || acc2.column_name
                     FROM all_constraints ac2
                     JOIN all_cons_columns acc2 ON ac2.constraint_name = acc2.constraint_name
                     WHERE ac2.constraint_name = cc.r_constraint_name
                     AND ROWNUM = 1)
                ELSE NULL
            END AS key_info
        FROM user_tab_columns c
        LEFT JOIN user_col_comments cm
            ON cm.table_name = c.table_name
            AND cm.column_name = c.column_name
        LEFT JOIN user_tab_comments tc
            ON tc.table_name = c.table_name
        LEFT JOIN user_cons_columns acc
            ON acc.table_name = c.table_name
            AND acc.column_name = c.column_name
        LEFT JOIN user_constraints cc
            ON cc.constraint_name = acc.constraint_name
            AND cc.constraint_type IN ('P', 'R')
        ORDER BY c.table_name, c.column_id
    ) LOOP
        
        IF rec.table_name != l_prev_tbl THEN
            IF l_prev_tbl IS NOT NULL THEN
                l_schema := l_schema || CHR(10);
            END IF;
            l_schema := l_schema || 'TABLE ' || rec.table_name;
            IF rec.tbl_comment IS NOT NULL THEN
                l_schema := l_schema || ' -- ' || rec.tbl_comment;
            END IF;
            l_schema := l_schema || CHR(10);
            l_prev_tbl := rec.table_name;
        END IF;

        l_schema := l_schema || '  ' || rec.column_name || ' ' || rec.data_type;

   
        IF rec.key_info IS NOT NULL THEN
            l_schema := l_schema || ' [' || rec.key_info || ']';
        END IF;

       
        IF rec.col_comment IS NOT NULL THEN
            l_schema := l_schema || ' -- ' || rec.col_comment;
        END IF;

        l_schema := l_schema || CHR(10);
    END LOOP;

 
    l_raw := apex_ai.generate(
        p_prompt =>
        'You are an expert Oracle SQL generator.' || CHR(10) ||
        'Here is the complete database schema:' || CHR(10) ||
        l_schema || CHR(10) ||
        'Rules:' || CHR(10) ||
        '1. Return ONLY one raw SQL SELECT statement.' || CHR(10) ||
        '2. Use ONLY the exact table and column names from the schema above.' || CHR(10) ||
        '3. Use proper JOINs based on FK relationships shown.' || CHR(10) ||
        '4. No explanations. No markdown. No code blocks. No semicolon.' || CHR(10) ||
        '5. Select only the columns relevant to the user request. Avoid SELECT *.' || CHR(10) ||
        '6. Always use table aliases like e, d — never use AS keyword for table aliases.' || CHR(10) ||
        '7. For column aliases use AS keyword only for columns, not for tables.' || CHR(10) ||
        '8. Example of correct JOIN: SELECT e.name, d.dept_name FROM employees e JOIN departments d ON e.dept_id = d.dept_id' || CHR(10) ||
        '9. Never wrap the query in parentheses or subqueries unless necessary.' || CHR(10) ||
        '10. For location/country based queries, use LIKE or IN with possible city names instead of exact country match.' || CHR(10) ||
'11. Never filter by country name if the column stores city names. Use city names directly.' || CHR(10) ||
        'User request: ' || apex_application.g_x01,
        -- p_prompt =>
        --     'You are an expert Oracle SQL generator.' || CHR(10) ||
        --     'Here is the complete database schema:' || CHR(10) ||
        --     l_schema || CHR(10) ||
        --     'Rules:' || CHR(10) ||
        --     '1. Return ONLY one raw SQL SELECT statement.' || CHR(10) ||
        --     '2. Use ONLY the exact table and column names from the schema above.' || CHR(10) ||
        --     '3. Use proper JOINs based on FK relationships shown.' || CHR(10) ||
        --     '4. No explanations. No markdown. No code blocks. No semicolon.' || CHR(10) ||
        --     'User request: ' || apex_application.g_x01,
        p_service_static_id => 'COHERE_ASSISTANT'
    );

   
    IF INSTR(l_raw, '```') > 0 THEN
        l_start := INSTR(l_raw, '```sql');
        IF l_start > 0 THEN
            l_start := INSTR(l_raw, CHR(10), l_start) + 1;
        ELSE
            l_start := INSTR(l_raw, '```') + 3;
            l_start := INSTR(l_raw, CHR(10), l_start) + 1;
        END IF;
        l_sql := TRIM(SUBSTR(l_raw, l_start, INSTR(l_raw, '```', l_start) - l_start));
    ELSE
        l_start := INSTR(UPPER(l_raw), 'SELECT');
        IF l_start = 0 THEN l_start := INSTR(UPPER(l_raw), 'WITH'); END IF;
        l_sql := TRIM(SUBSTR(l_raw, l_start));
    END IF;

 
    IF SUBSTR(TRIM(l_sql), -1) = ';' THEN
        l_sql := TRIM(SUBSTR(TRIM(l_sql), 1, LENGTH(TRIM(l_sql)) - 1));
    END IF;

    -- Security: only allow SELECT or WITH
    IF UPPER(SUBSTR(TRIM(l_sql), 1, 6)) NOT IN ('SELECT', 'WITH  ') THEN
        HTP.P('{"error":"Only SELECT queries are allowed."}');
        RETURN;
    END IF;

   
    l_cursor := DBMS_SQL.OPEN_CURSOR;
    DBMS_SQL.PARSE(l_cursor, l_sql, DBMS_SQL.NATIVE);
    DBMS_SQL.DESCRIBE_COLUMNS(l_cursor, l_col_cnt, l_desc);

    FOR i IN 1..l_col_cnt LOOP
        DBMS_SQL.DEFINE_COLUMN(l_cursor, i, l_val, 4000);
        IF i > 1 THEN l_cols := l_cols || ','; END IF;
        l_cols := l_cols || '"' || escape_json(l_desc(i).col_name) || '"';
    END LOOP;

    IF DBMS_SQL.EXECUTE(l_cursor) >= 0 THEN
        WHILE DBMS_SQL.FETCH_ROWS(l_cursor) > 0 LOOP
            DECLARE l_row CLOB := '['; BEGIN
                FOR i IN 1..l_col_cnt LOOP
                    DBMS_SQL.COLUMN_VALUE(l_cursor, i, l_val);
                    IF i > 1 THEN l_row := l_row || ','; END IF;
                    l_row := l_row || '"' || escape_json(l_val) || '"';
                END LOOP;
                l_row := l_row || ']';
                IF l_row_cnt > 0 THEN l_rows := l_rows || ','; END IF;
                l_rows := l_rows || l_row;
                l_row_cnt := l_row_cnt + 1;
            END;
        END LOOP;
    END IF;

    DBMS_SQL.CLOSE_CURSOR(l_cursor);

    l_json := '{"sql":"' || escape_json(l_sql) ||
              '","columns":[' || l_cols ||
              '],"rows":[' || l_rows || ']}';
    HTP.P(l_json);

EXCEPTION WHEN OTHERS THEN
    IF DBMS_SQL.IS_OPEN(l_cursor) THEN
        DBMS_SQL.CLOSE_CURSOR(l_cursor);
    END IF;
    HTP.P('{"error":"' || escape_json(SQLERRM) || '"}');
END;