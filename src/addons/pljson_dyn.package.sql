CREATE OR REPLACE PACKAGE pljson_dyn AUTHID CURRENT_USER AS
    null_as_empty_string BOOLEAN NOT NULL := TRUE; --varchar2
    include_dates        BOOLEAN NOT NULL := TRUE;
    include_clobs        BOOLEAN NOT NULL := TRUE;
    include_blobs        BOOLEAN NOT NULL := FALSE;
    include_arrays       BOOLEAN NOT NULL := TRUE;  -- pljson_varray or pljson_narray

    /* list with objects */
    FUNCTION executelist
    (
        stmt    VARCHAR2,
        bindvar pljson DEFAULT NULL,
        cur_num NUMBER DEFAULT NULL
    ) RETURN pljson_list;

    /* object with lists */
    FUNCTION executeobject
    (
        stmt    VARCHAR2,
        bindvar pljson DEFAULT NULL,
        cur_num NUMBER DEFAULT NULL
    ) RETURN pljson;

    $if DBMS_DB_VERSION.ver_le_11_2 $then
    FUNCTION executelist(stmt IN OUT SYS_REFCURSOR) RETURN pljson_list;
    FUNCTION executeobject(stmt IN OUT SYS_REFCURSOR) RETURN pljson;
    $end

END pljson_dyn;
/

CREATE OR REPLACE PACKAGE BODY pljson_dyn AS

    $if DBMS_DB_VERSION.ver_le_11_2 $then

    FUNCTION executelist(stmt IN OUT SYS_REFCURSOR) RETURN pljson_list AS
        l_cur NUMBER;
    BEGIN
        l_cur := dbms_sql.to_cursor_number(stmt);
        RETURN pljson_dyn.executelist(NULL, NULL, l_cur);
    END;

    FUNCTION executeobject(stmt IN OUT SYS_REFCURSOR) RETURN pljson AS
        l_cur NUMBER;
    BEGIN
        l_cur := dbms_sql.to_cursor_number(stmt);
        RETURN pljson_dyn.executeobject(NULL, NULL, l_cur);
    END;
    $end

    PROCEDURE bind_json
    (
        l_cur   NUMBER,
        bindvar pljson
    ) AS
        keylist pljson_list := bindvar.get_keys();
    BEGIN
        FOR i IN 1 .. keylist.count LOOP
            IF (bindvar.get(i).get_type = 'number') THEN
                dbms_sql.bind_variable(l_cur,
                                       ':' || keylist.get(i).get_string,
                                       bindvar.get(i).get_number);
            ELSIF (bindvar.get(i).get_type = 'array') THEN
                DECLARE
                    v_bind dbms_sql.varchar2_table;
                    v_arr  pljson_list := pljson_list(bindvar.get(i));
                BEGIN
                    FOR j IN 1 .. v_arr.count LOOP
                        v_bind(j) := v_arr.get(j).value_of;
                    END LOOP;
                    dbms_sql.bind_array(l_cur,
                                        ':' || keylist.get(i).get_string,
                                        v_bind);
                END;
            ELSE
                dbms_sql.bind_variable(l_cur,
                                       ':' || keylist.get(i).get_string,
                                       bindvar.get(i).value_of());
            END IF;
        END LOOP;
    END bind_json;

    /* list with objects */
    FUNCTION executelist
    (
        stmt    VARCHAR2,
        bindvar pljson,
        cur_num NUMBER
    ) RETURN pljson_list AS
        l_cur      NUMBER;
        l_dtbl     dbms_sql.desc_tab3;
        l_cnt      NUMBER;
        l_status   NUMBER;
        l_val      VARCHAR2(4000);
        outer_list pljson_list := pljson_list();
        inner_obj  pljson;
        conv       NUMBER;
        read_date  DATE;
        read_clob  CLOB;
        read_blob  BLOB;
        col_type   NUMBER;
        read_varray pljson_varray;
        read_narray pljson_narray;
    BEGIN
        IF (cur_num IS NOT NULL) THEN
            l_cur := cur_num;
        ELSE
            l_cur := dbms_sql.open_cursor;
            dbms_sql.parse(l_cur, stmt, dbms_sql.native);
            IF (bindvar IS NOT NULL) THEN
                bind_json(l_cur, bindvar);
            END IF;
        END IF;
        dbms_sql.describe_columns3(l_cur, l_cnt, l_dtbl);
        FOR i IN 1 .. l_cnt LOOP
            col_type := l_dtbl(i).col_type;
            --do.pl(col_type);
            IF (col_type = 12) THEN
                dbms_sql.define_column(l_cur, i, read_date);
            ELSIF (col_type = 112) THEN
                dbms_sql.define_column(l_cur, i, read_clob);
            ELSIF (col_type = 113) THEN
                dbms_sql.define_column(l_cur, i, read_blob);
            ELSIF (col_type IN (1, 2, 96)) THEN
                dbms_sql.define_column(l_cur, i, l_val, 4000);
       elsif(col_type = 109 and l_dtbl(i).col_type_name = 'PLJSON_VARRAY') then
         dbms_sql.define_column(l_cur,i,read_varray);
       elsif(col_type = 109 and l_dtbl(i).col_type_name = 'PLJSON_NARRAY') then
         dbms_sql.define_column(l_cur,i,read_narray);
       else
         dbms_output.put_line('unhandled col_type =' || col_type);
            END IF;
        END LOOP;
    
        IF (cur_num IS NULL) THEN
            l_status := dbms_sql.execute(l_cur);
        END IF;
    
        WHILE (dbms_sql.fetch_rows(l_cur) > 0) LOOP
            inner_obj := pljson();
            FOR i IN 1 .. l_cnt LOOP
                CASE TRUE
                    WHEN l_dtbl(i).col_type IN (1, 96) THEN
                        -- varchar2
                        dbms_sql.column_value(l_cur, i, l_val);
                        IF (l_val IS NULL) THEN
                            IF (null_as_empty_string) THEN
                                inner_obj.put(l_dtbl(i).col_name, ''); --treatet as emptystring?
                            ELSE
                                inner_obj.put(l_dtbl(i).col_name,
                                              pljson_value.makenull); --null
                            END IF;
                        ELSE
                            inner_obj.put(l_dtbl(i).col_name,
                                          pljson_value(l_val)); --null
                        END IF;
                        --do.pl(l_dtbl(i).col_name||' --> '||l_val||'varchar2' ||l_dtbl(i).col_type);
                    WHEN l_dtbl(i).col_type = 2 THEN
                        -- number
                        dbms_sql.column_value(l_cur, i, l_val);
                        conv := l_val;
                        inner_obj.put(l_dtbl(i).col_name, conv);
                        -- do.pl(l_dtbl(i).col_name||' --> '||l_val||'number ' ||l_dtbl(i).col_type);
                    WHEN l_dtbl(i).col_type = 12 THEN
                        -- date
                        IF (include_dates) THEN
                            dbms_sql.column_value(l_cur, i, read_date);
                            inner_obj.put(l_dtbl(i).col_name,
                                          pljson_ext.to_json_value(read_date));
                        END IF;
                        --do.pl(l_dtbl(i).col_name||' --> '||l_val||'date ' ||l_dtbl(i).col_type);
                    WHEN l_dtbl(i).col_type = 112 THEN
                        --clob
                        IF (include_clobs) THEN
                            dbms_sql.column_value(l_cur, i, read_clob);
                            inner_obj.put(l_dtbl(i).col_name,
                                          pljson_value(read_clob));
                        END IF;
                    WHEN l_dtbl(i).col_type = 113 THEN
                        --blob
                        IF (include_blobs) THEN
                            dbms_sql.column_value(l_cur, i, read_blob);
                            IF (dbms_lob.getlength(read_blob) > 0) THEN
                                inner_obj.put(l_dtbl(i).col_name,
                                              pljson_ext.encode(read_blob));
                            ELSE
                                inner_obj.put(l_dtbl(i).col_name,
                                              pljson_value.makenull);
                            END IF;
                        END IF;
         when l_dtbl(i).col_type = 109 and l_dtbl(i).col_type_name = 'PLJSON_VARRAY' then
           if (include_arrays) then
             dbms_sql.column_value(l_cur,i,read_varray);
             inner_obj.put(l_dtbl(i).col_name, pljson_list(read_varray));
           end if;
         when l_dtbl(i).col_type = 109 and l_dtbl(i).col_type_name = 'PLJSON_NARRAY' then
           if (include_arrays) then
             dbms_sql.column_value(l_cur,i,read_narray);
             inner_obj.put(l_dtbl(i).col_name, pljson_list(read_narray));
           end if;
      
                    ELSE
                        NULL; --discard other types
                END CASE;
            END LOOP;
            outer_list.append(inner_obj.to_json_value);
        END LOOP;
        dbms_sql.close_cursor(l_cur);
        RETURN outer_list;
    END executelist;

    /* object with lists */
    FUNCTION executeobject
    (
        stmt    VARCHAR2,
        bindvar pljson,
        cur_num NUMBER
    ) RETURN pljson AS
        l_cur            NUMBER;
        l_dtbl           dbms_sql.desc_tab;
        l_cnt            NUMBER;
        l_status         NUMBER;
        l_val            VARCHAR2(4000);
        inner_list_names pljson_list := pljson_list();
        inner_list_data  pljson_list := pljson_list();
        data_list        pljson_list;
        outer_obj        pljson := pljson();
        conv             NUMBER;
        read_date        DATE;
        read_clob        CLOB;
        read_blob        BLOB;
        col_type         NUMBER;
    BEGIN
        IF (cur_num IS NOT NULL) THEN
            l_cur := cur_num;
        ELSE
            l_cur := dbms_sql.open_cursor;
            dbms_sql.parse(l_cur, stmt, dbms_sql.native);
            IF (bindvar IS NOT NULL) THEN
                bind_json(l_cur, bindvar);
            END IF;
        END IF;
        dbms_sql.describe_columns(l_cur, l_cnt, l_dtbl);
        FOR i IN 1 .. l_cnt LOOP
            col_type := l_dtbl(i).col_type;
            IF (col_type = 12) THEN
                dbms_sql.define_column(l_cur, i, read_date);
            ELSIF (col_type = 112) THEN
                dbms_sql.define_column(l_cur, i, read_clob);
            ELSIF (col_type = 113) THEN
                dbms_sql.define_column(l_cur, i, read_blob);
            ELSIF (col_type IN (1, 2, 96)) THEN
                dbms_sql.define_column(l_cur, i, l_val, 4000);
            END IF;
        END LOOP;
        IF (cur_num IS NULL) THEN
            l_status := dbms_sql.execute(l_cur);
        END IF;
    
        FOR i IN 1 .. l_cnt LOOP
            CASE l_dtbl(i).col_type
                WHEN 1 THEN
                    inner_list_names.append(l_dtbl(i).col_name);
                WHEN 96 THEN
                    inner_list_names.append(l_dtbl(i).col_name);
                WHEN 2 THEN
                    inner_list_names.append(l_dtbl(i).col_name);
                WHEN 12 THEN
                    IF (include_dates) THEN
                        inner_list_names.append(l_dtbl(i).col_name);
                    END IF;
                WHEN 112 THEN
                    IF (include_clobs) THEN
                        inner_list_names.append(l_dtbl(i).col_name);
                    END IF;
                WHEN 113 THEN
                    IF (include_blobs) THEN
                        inner_list_names.append(l_dtbl(i).col_name);
                    END IF;
                ELSE
                    NULL;
            END CASE;
        END LOOP;
    
        WHILE (dbms_sql.fetch_rows(l_cur) > 0) LOOP
            data_list := pljson_list();
            FOR i IN 1 .. l_cnt LOOP
                CASE TRUE
                    WHEN l_dtbl(i).col_type IN (1, 96) THEN
                        -- varchar2
                        dbms_sql.column_value(l_cur, i, l_val);
                        IF (l_val IS NULL) THEN
                            IF (null_as_empty_string) THEN
                                data_list.append(''); --treatet as emptystring?
                            ELSE
                                data_list.append(pljson_value.makenull); --null
                            END IF;
                        ELSE
                            data_list.append(pljson_value(l_val)); --null
                        END IF;
                        --do.pl(l_dtbl(i).col_name||' --> '||l_val||'varchar2' ||l_dtbl(i).col_type);
                --handling number types
                    WHEN l_dtbl(i).col_type = 2 THEN
                        -- number
                        dbms_sql.column_value(l_cur, i, l_val);
                        conv := l_val;
                        data_list.append(conv);
                        -- do.pl(l_dtbl(i).col_name||' --> '||l_val||'number ' ||l_dtbl(i).col_type);
                    WHEN l_dtbl(i).col_type = 12 THEN
                        -- date
                        IF (include_dates) THEN
                            dbms_sql.column_value(l_cur, i, read_date);
                            data_list.append(pljson_ext.to_json_value(read_date));
                        END IF;
                        --do.pl(l_dtbl(i).col_name||' --> '||l_val||'date ' ||l_dtbl(i).col_type);
                    WHEN l_dtbl(i).col_type = 112 THEN
                        --clob
                        IF (include_clobs) THEN
                            dbms_sql.column_value(l_cur, i, read_clob);
                            data_list.append(pljson_value(read_clob));
                        END IF;
                    WHEN l_dtbl(i).col_type = 113 THEN
                        --blob
                        IF (include_blobs) THEN
                            dbms_sql.column_value(l_cur, i, read_blob);
                            IF (dbms_lob.getlength(read_blob) > 0) THEN
                                data_list.append(pljson_ext.encode(read_blob));
                            ELSE
                                data_list.append(pljson_value.makenull);
                            END IF;
                        END IF;
                    ELSE
                        NULL; --discard other types
                END CASE;
            END LOOP;
            inner_list_data.append(data_list);
        END LOOP;
    
        outer_obj.put('names', inner_list_names.to_json_value);
        outer_obj.put('data', inner_list_data.to_json_value);
        dbms_sql.close_cursor(l_cur);
        RETURN outer_obj;
    END executeobject;

END pljson_dyn;
/

/*
DECLARE
    res pljson_list;
BEGIN
    res := pljson_dyn.executelist('select :bindme as one, :lala as two from dual where dummy in :arraybind',
                                pljson('{bindme:"4", lala:123, arraybind:[1,2,3,"X"]}'));
    res.print;
END;
  */
