
create or replace type pljson_varray as table of varchar2(32767);
/

create or replace type pljson_vtab as table of pljson_varray;
/

create or replace type pljson_narray as table of number;
/


CREATE OR REPLACE TYPE pljson_table AS OBJECT
(

    str CLOB, -- varchar2(32767),
/*
    for 'nested' mode paths must use the [*] path operator
  */
    column_paths pljson_varray,
    column_names pljson_varray,
    table_mode   VARCHAR2(20),

/*
    'cartessian' mode uses only
    data_tab, row_ind
  */
    data_tab pljson_vtab,
/*
    'nested' mode uses only
    row_ind, row_count, nested_path
    column_nested_index
    last_nested_index

    for row_ind, row_count, nested_path
    each entry corresponds to a [*] in the full path of the last column
    and there will be the same or fewer entries than columns
    1st nested path corresponds to whole array as '[*]'
    or to root object as '' or to array within root object as 'key1.key2...array[*]'

    column_nested_index maps column index to nested_... index
  */
    row_ind   pljson_narray,
    row_count pljson_narray,
/*
    nested_path_full = full path, up to and including last [*], but not dot notation to key
    nested_path_ext = extension to previous nested path
    column_path_part = extension to nested_path_full, the dot notation to key after last [*]
    column_path = nested_path_full || column_path_part

    start_column = start column where nested path appears first
    nested_path_literal = nested_path_full with * replaced with literal integers, for fetching

    column_path = a[*].b.c[*].e
    nested_path_full = a[*].b.c[*]
    nested_path_ext = .b.c[*]
    column_path_part = .e
  */
    nested_path_full    pljson_varray,
    nested_path_ext     pljson_varray,
    start_column        pljson_narray,
    nested_path_literal pljson_varray,

    column_nested_index pljson_narray,
    column_path_part    pljson_varray,
    column_val          pljson_varray,

/* if the root of the document is array, the size of the array */
    root_array_size NUMBER,

/* the parsed json_obj */
    json_obj pljson,

    ret_type anytype,

    STATIC FUNCTION odcitabledescribe
    (
        rtype        OUT anytype,
        json_str     CLOB,
        column_paths pljson_varray,
        column_names pljson_varray := NULL,
        table_mode   VARCHAR2 := 'cartessian'
    ) RETURN NUMBER,

    STATIC FUNCTION odcitableprepare
    (
        sctx         OUT pljson_table_impl,
        ti           IN sys.odcitabfuncinfo,
        json_str     CLOB,
        column_paths pljson_varray,
        column_names pljson_varray := NULL,
        table_mode   VARCHAR2 := 'cartessian'
    ) RETURN NUMBER,

    STATIC FUNCTION odcitablestart
    (
        sctx         IN OUT pljson_table_impl,
        json_str     CLOB,
        column_paths pljson_varray,
        column_names pljson_varray := NULL,
        table_mode   VARCHAR2 := 'cartessian'
    ) RETURN NUMBER,

    MEMBER FUNCTION odcitablefetch
    (
        SELF   IN OUT pljson_table_impl,
        nrows  IN NUMBER,
        outset OUT anydataset
    ) RETURN NUMBER,

    MEMBER FUNCTION odcitableclose(SELF IN pljson_table_impl) RETURN NUMBER,

    STATIC FUNCTION json_table
    (
        json_str     CLOB,
        column_paths pljson_varray,
        column_names pljson_varray := NULL,
        table_mode   VARCHAR2 := 'cartessian'
    ) RETURN anydataset
        PIPELINED USING pljson_table_impl
);
/

CREATE OR REPLACE TYPE BODY pljson_table AS


    STATIC FUNCTION odcitabledescribe
    (
        rtype        OUT anytype,
        json_str     CLOB,
        column_paths pljson_varray,
        column_names pljson_varray := NULL,
        table_mode   VARCHAR2 := 'cartessian'
    ) RETURN NUMBER IS
        atyp anytype;
    BEGIN
    
        anytype.begincreate(dbms_types.typecode_object, atyp);
        IF column_names IS NULL THEN
            FOR i IN column_paths.first .. column_paths.last LOOP
                atyp.addattr('JSON_' || ltrim(to_char(i)),
                             dbms_types.typecode_varchar2,
                             NULL,
                             NULL,
                             32767,
                             NULL,
                             NULL);
            END LOOP;
        ELSE
            FOR i IN column_names.first .. column_names.last LOOP
                atyp.addattr(upper(column_names(i)),
                             dbms_types.typecode_varchar2,
                             NULL,
                             NULL,
                             32767,
                             NULL,
                             NULL);
            END LOOP;
        END IF;
        atyp.endcreate;
    
        anytype.begincreate(dbms_types.typecode_table, rtype);
        rtype.setinfo(NULL,
                      NULL,
                      NULL,
                      NULL,
                      NULL,
                      atyp,
                      dbms_types.typecode_object,
                      0);
        rtype.endcreate();
    
        RETURN odciconst.success;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN odciconst.error;
    END;

    STATIC FUNCTION odcitableprepare
    (
        sctx         OUT pljson_table_impl,
        ti           IN sys.odcitabfuncinfo,
        json_str     CLOB,
        column_paths pljson_varray,
        column_names pljson_varray := NULL,
        table_mode   VARCHAR2 := 'cartessian'
    ) RETURN NUMBER IS
        elem_typ sys.anytype;
        prec     PLS_INTEGER;
        scale    PLS_INTEGER;
        len      PLS_INTEGER;
        csid     PLS_INTEGER;
        csfrm    PLS_INTEGER;
        tc       PLS_INTEGER;
        aname    VARCHAR2(30);
    BEGIN
    
        tc   := ti.rettype.getattreleminfo(1,
                                           prec,
                                           scale,
                                           len,
                                           csid,
                                           csfrm,
                                           elem_typ,
                                           aname);
        sctx := pljson_table_impl(json_str,
                                  column_paths,
                                  column_names,
                                  table_mode,
                                  pljson_vtab(),
                                  pljson_narray(),
                                  pljson_narray(),
                                  pljson_varray(),
                                  pljson_varray(),
                                  pljson_narray(),
                                  pljson_varray(),
                                  pljson_narray(),
                                  pljson_varray(),
                                  pljson_varray(),
                                  0,
                                  pljson(),
                                  elem_typ);
        RETURN odciconst.success;
    END;

    STATIC FUNCTION odcitablestart
    (
        sctx         IN OUT pljson_table_impl,
        json_str     CLOB,
        column_paths pljson_varray,
        column_names pljson_varray := NULL,
        table_mode   VARCHAR2 := 'cartessian'
    ) RETURN NUMBER IS
        json_obj    pljson;
        json_val    pljson_value;
        buf         VARCHAR2(32767);
        json_arr    pljson_list;
        json_elem   pljson_value;
        value_array pljson_varray := pljson_varray();
    
        root_val        pljson_value;
        root_list       pljson_list;
        root_array_size NUMBER := 0;
        /* for nested mode */
        last_nested_path_full VARCHAR2(32767);
        column_path           VARCHAR(32767);
        array_pos             NUMBER;
        nested_path_prefix    VARCHAR2(32767);
        nested_path_ext       VARCHAR2(32767);
        column_path_part      VARCHAR2(32767);
    
        FUNCTION starts_with
        (
            a IN VARCHAR2,
            b IN VARCHAR2
        ) RETURN BOOLEAN IS
        BEGIN
            RETURN b IS NULL OR instr(a, b) = 1;
        END;
    BEGIN
    
        root_val := pljson_parser.parse_any(json_str);
        IF root_val.typeval = 2 THEN
            root_list       := pljson_list(root_val);
            root_array_size := root_list.count;
            json_obj        := pljson(root_list);
        ELSE
            root_array_size := 1;
            json_obj        := pljson(root_val);
        END IF;
    
        sctx.json_obj        := json_obj;
        sctx.table_mode      := table_mode;
        sctx.root_array_size := root_array_size;
        sctx.data_tab.delete;
    
        IF table_mode = 'cartessian' THEN
            FOR i IN column_paths.first .. column_paths.last LOOP
                json_val := pljson_ext.get_json_value(json_obj,
                                                      column_paths(i));
                CASE json_val.typeval
                --when 1 then 'object';
                    WHEN 2 THEN
                        -- 'array';
                        json_arr := pljson_list(json_val);
                        value_array.delete;
                        FOR j IN 1 .. json_arr.count LOOP
                            json_elem := json_arr.get(j);
                            CASE json_elem.typeval
                            --when 1 then 'object';
                            --when 2 then -- 'array';
                                WHEN 3 THEN
                                    -- 'string';
                                    buf := json_elem.get_string();
                                    --do.pl('res[](string)='||buf);
                                    value_array.extend();
                                    value_array(value_array.last) := buf;
                                WHEN 4 THEN
                                    -- 'number';
                                    buf := to_char(json_elem.get_number());
                                    --do.pl('res[](number)='||buf);
                                    value_array.extend();
                                    value_array(value_array.last) := buf;
                                WHEN 5 THEN
                                    -- 'bool';
                                    buf := CASE json_elem.get_bool()
                                               WHEN TRUE THEN
                                                'true'
                                               WHEN FALSE THEN
                                                'false'
                                           END;
                                    --do.pl('res[](bool)='||buf);
                                    value_array.extend();
                                    value_array(value_array.last) := buf;
                                WHEN 6 THEN
                                    -- 'null';
                                    buf := NULL;
                                    --do.pl('res[](null)='||buf);
                                    value_array.extend();
                                    value_array(value_array.last) := buf;
                                ELSE
                                    -- if object is unknown or does not exist add new element of type null
                                    buf := NULL;
                                    --do.pl('res[](unknown)='||buf);
                                    sctx.data_tab.extend();
                                    sctx.data_tab(sctx.data_tab.last) := pljson_varray(buf);
                            END CASE;
                        END LOOP;
                        sctx.data_tab.extend();
                        sctx.data_tab(sctx.data_tab.last) := value_array;
                    WHEN 3 THEN
                        -- 'string';
                        buf := json_val.get_string();
                        --do.pl('res(string)='||buf);
                        sctx.data_tab.extend();
                        sctx.data_tab(sctx.data_tab.last) := pljson_varray(buf);
                    WHEN 4 THEN
                        -- 'number';
                        buf := to_char(json_val.get_number());
                        --do.pl('res(number)='||buf);
                        sctx.data_tab.extend();
                        sctx.data_tab(sctx.data_tab.last) := pljson_varray(buf);
                    WHEN 5 THEN
                        -- 'bool';
                        buf := CASE json_val.get_bool()
                                   WHEN TRUE THEN
                                    'true'
                                   WHEN FALSE THEN
                                    'false'
                               END;
                        --do.pl('res(bool)='||buf);
                        sctx.data_tab.extend();
                        sctx.data_tab(sctx.data_tab.last) := pljson_varray(buf);
                    WHEN 6 THEN
                        -- 'null';
                        buf := NULL;
                        --do.pl('res(null)='||buf);
                        sctx.data_tab.extend();
                        sctx.data_tab(sctx.data_tab.last) := pljson_varray(buf);
                    ELSE
                        -- if object is unknown or does not exist add new element of type null
                        buf := NULL;
                        --do.pl('res(unknown)='||buf);
                        sctx.data_tab.extend();
                        sctx.data_tab(sctx.data_tab.last) := pljson_varray(buf);
                END CASE;
            END LOOP;
        
            sctx.row_ind.delete;
            FOR i IN column_paths.first .. column_paths.last LOOP
                sctx.row_ind.extend();
                sctx.row_ind(sctx.row_ind.last) := 1;
            END LOOP;
        ELSE
            sctx.nested_path_full.delete;
            sctx.nested_path_ext.delete;
            sctx.column_path_part.delete;
            sctx.column_nested_index.delete;
            FOR i IN column_paths.first .. column_paths.last LOOP
                --do.pl(i || ', column_path = ' || column_paths(i));
                column_path := column_paths(i);
                array_pos   := instr(column_path, '[*]', -1);
                IF array_pos > 0 THEN
                    nested_path_prefix := substr(column_path,
                                                 1,
                                                 array_pos + 2);
                ELSE
                    nested_path_prefix := '';
                END IF;
                --do.pl(i || ', nested_path_prefix = ' || nested_path_prefix);
                last_nested_path_full := '';
                IF sctx.nested_path_full.last IS NOT NULL THEN
                    last_nested_path_full := sctx.nested_path_full(sctx.nested_path_full.last);
                END IF;
                --do.pl(i || ', last_nested_path_full = ' || last_nested_path_full);
                IF NOT
                    starts_with(nested_path_prefix, last_nested_path_full) THEN
                    --do.pl('column paths are not nested, column# ' || i);
                    raise_application_error(-20120,
                                            'column paths are not nested, column# ' || i);
                END IF;
                IF i = 1 OR nested_path_prefix != last_nested_path_full OR
                   (nested_path_prefix IS NOT NULL AND
                   last_nested_path_full IS NULL) THEN
                    nested_path_ext := substr(nested_path_prefix,
                                              nvl(length(last_nested_path_full),
                                                  0) + 1);
                    IF instr(nested_path_ext, '[*]') !=
                       instr(nested_path_ext, '[*]', -1) THEN
                        --do.pl('column introduces more than one array, column# ' || i);
                        raise_application_error(-20120,
                                                'column introduces more than one array, column# ' || i);
                    END IF;
                    sctx.nested_path_full.extend();
                    sctx.nested_path_full(sctx.nested_path_full.last) := nested_path_prefix;
                    --do.pl(i || ', new nested_path_full = ' || nested_path_prefix);
                    sctx.nested_path_ext.extend();
                    sctx.nested_path_ext(sctx.nested_path_ext.last) := nested_path_ext;
                    --do.pl(i || ', new nested_path_ext = ' || nested_path_ext);
                    sctx.start_column.extend();
                    sctx.start_column(sctx.start_column.last) := i;
                END IF;
                sctx.column_nested_index.extend();
                sctx.column_nested_index(sctx.column_nested_index.last) := sctx.nested_path_full.last;
                --do.pl(i || ', column_nested_index = ' || sctx.nested_path_full.LAST);
                column_path_part := substr(column_path,
                                           nvl(length(nested_path_prefix), 0) + 1);
                sctx.column_path_part.extend();
                sctx.column_path_part(sctx.column_path_part.last) := column_path_part;
                --do.pl(i || ', column_path_part = ' || column_path_part);
            END LOOP;
            --do.pl('initialize row indexes');
            sctx.row_ind.delete;
            sctx.row_count.delete;
            sctx.nested_path_literal.delete;
            sctx.column_val.delete;
            IF sctx.nested_path_full.last IS NOT NULL THEN
                FOR i IN 1 .. sctx.nested_path_full.last LOOP
                    sctx.row_ind.extend();
                    sctx.row_ind(sctx.row_ind.last) := -1;
                    sctx.row_count.extend();
                    sctx.row_count(sctx.row_count.last) := -1;
                    sctx.nested_path_literal.extend();
                    sctx.nested_path_literal(sctx.nested_path_literal.last) := '';
                END LOOP;
            END IF;
            FOR i IN 1 .. sctx.column_paths.last LOOP
                sctx.column_val.extend();
                sctx.column_val(sctx.column_val.last) := '';
            END LOOP;
        END IF;
    
        RETURN odciconst.success;
    END;

    MEMBER FUNCTION odcitablefetch
    (
        SELF   IN OUT pljson_table_impl,
        nrows  IN NUMBER,
        outset OUT anydataset
    ) RETURN NUMBER IS
        --data_row pljson_varray := pljson_varray();
        --type index_array is table of number;
        --row_ind index_array := index_array();
        j        NUMBER;
        num_rows NUMBER := 0;
    
        --json_obj pljson;
        json_val pljson_value;
        buf      VARCHAR2(32767);
        --data_tab pljson_vtab := pljson_vtab();
        json_arr    pljson_list;
        json_elem   pljson_value;
        value_array pljson_varray := pljson_varray();
    
        /* nested mode */
        temp_path   VARCHAR(32767);
        start_index NUMBER;
        k           NUMBER;
        /*
          k is nested path index and not column index
          sets row_count()
        */
        PROCEDURE set_count(k NUMBER) IS
            temp_path VARCHAR(32767);
        BEGIN
            IF k = 1 THEN
                IF nested_path_full(1) IS NULL OR
                   nested_path_full(1) = '[*]' THEN
                    row_count(1) := root_array_size;
                    RETURN;
                ELSE
                    temp_path := substr(nested_path_full(1),
                                        1,
                                        length(nested_path_full(1)) - 3);
                END IF;
            ELSE
                temp_path := nested_path_literal(k - 1) ||
                             substr(nested_path_ext(k),
                                    1,
                                    length(nested_path_ext(k)) - 3);
            END IF;
            --dbms_output.put_line(k || ', set_count temp_path = ' || temp_path);
            json_val := pljson_ext.get_json_value(json_obj, temp_path);
            IF json_val.typeval != 2 THEN
                raise_application_error(-20120,
                                        'column introduces array with [*] but is not array in json, column# ' || k);
            END IF;
            row_count(k) := pljson_list(json_val).count;
        END;
        /*
          k is nested path index and not column index
          sets nested_path_literal() for row_ind(k)
        */
        PROCEDURE set_nested_path_literal(k NUMBER) IS
            temp_path VARCHAR(32767);
        BEGIN
            IF k = 1 THEN
                IF nested_path_full(1) IS NULL THEN
                    RETURN;
                END IF;
                temp_path := substr(nested_path_full(1),
                                    1,
                                    length(nested_path_full(1)) - 2);
            ELSE
                temp_path := nested_path_literal(k - 1) ||
                             substr(nested_path_ext(k),
                                    1,
                                    length(nested_path_ext(k)) - 2);
            END IF;
            nested_path_literal(k) := temp_path || row_ind(k) || ']';
        END;
    BEGIN
    
        IF table_mode = 'cartessian' THEN
            outset := NULL;
        
            IF row_ind(1) = 0 THEN
                RETURN odciconst.success;
            END IF;
        
            anydataset.begincreate(dbms_types.typecode_object,
                                   self.ret_type,
                                   outset);
        
            /* iterative cartesian product algorithm */
            <<main_loop>>
            WHILE TRUE LOOP
                EXIT WHEN num_rows = nrows OR row_ind(1) = 0;
                --data_row.delete;
                outset.addinstance;
                outset.piecewise();
                --do.pl('put one row piece');
                FOR i IN data_tab.first .. data_tab.last LOOP
                    --data_row.extend();
                    --data_row(data_row.LAST) := data_tab(i)(row_ind(i));
                    --do.pl('json_'||ltrim(to_char(i)));
                    --do.pl('['||ltrim(to_char(row_ind(i)))||']');
                    --do.pl('='||data_tab(i)(row_ind(i)));
                    outset.setvarchar2(data_tab(i) (row_ind(i)));
                END LOOP;
                --pipe row(data_row);
                num_rows := num_rows + 1;
            
                --do.pl('adjust row indexes');
                j := row_ind.count;
                <<index_loop>>
                WHILE TRUE LOOP
                    row_ind(j) := row_ind(j) + 1;
                    IF row_ind(j) <= data_tab(j).count THEN
                        EXIT index_loop;
                    END IF;
                    row_ind(j) := 1;
                    j := j - 1;
                    IF j < 1 THEN
                        row_ind(1) := 0; -- hack to indicate end of all fetches
                        EXIT main_loop;
                    END IF;
                END LOOP index_loop;
            END LOOP main_loop;
        
            outset.endcreate;
        
        ELSE
            /* fetch nested mode */
            outset := NULL;
        
            anydataset.begincreate(dbms_types.typecode_object,
                                   self.ret_type,
                                   outset);
        
            <<main_loop_nested>>
            WHILE TRUE LOOP
                /* find starting column */
                /*
                  in first run, loop will not assign value to start_index, so start_index := 0
                  in last run after all rows produced, the same will happen and start_index := 0
                  but the last run will have row_count(1) >= 0
                */
                start_index := 0;
                FOR i IN REVERSE row_ind.first .. row_ind.last LOOP
                    IF row_ind(i) < row_count(i) THEN
                        start_index := start_column(i);
                        EXIT;
                    END IF;
                END LOOP;
                IF start_index = 0 THEN
                    IF num_rows = nrows OR row_count(1) >= 0 THEN
                        EXIT main_loop_nested;
                    ELSE
                        start_index := 1;
                    END IF;
                END IF;
            
                /* fetch rows */
                --do.pl('fetch new row, start from column# '|| start_index);
                <<row_loop_nested>>
                FOR i IN start_index .. column_paths.last LOOP
                    k := column_nested_index(i);
                    /* new nested path */
                    IF start_column(k) = i THEN
                        --do.pl(i || ', new nested path');
                        /* new count */
                        IF row_ind(k) = row_count(k) THEN
                            set_count(k);
                            row_ind(k) := 0;
                            --do.pl(i || ', new nested count = ' || row_count(k));
                        END IF;
                        /* advance row_ind */
                        row_ind(k) := row_ind(k) + 1;
                        set_nested_path_literal(k);
                    END IF;
                    temp_path := nested_path_literal(k) ||
                                 column_path_part(i);
                    --do.pl(i || ', path = ' || temp_path);
                    json_val := pljson_ext.get_json_value(json_obj,
                                                          temp_path);
                    --do.pl('type='||json_val.get_type());
                    CASE json_val.typeval
                    --when 1 then 'object';
                    --when 2 then -- 'array';
                        WHEN 3 THEN
                            -- 'string';
                            buf := json_val.get_string();
                            --do.pl('res(string)='||buf);
                            column_val(i) := buf;
                        WHEN 4 THEN
                            -- 'number';
                            buf := to_char(json_val.get_number());
                            --do.pl('res(number)='||buf);
                            column_val(i) := buf;
                        WHEN 5 THEN
                            -- 'bool';
                            buf := CASE json_val.get_bool()
                                       WHEN TRUE THEN
                                        'true'
                                       WHEN FALSE THEN
                                        'false'
                                   END;
                            --do.pl('res(bool)='||buf);
                            column_val(i) := buf;
                        WHEN 6 THEN
                            -- 'null';
                            buf := NULL;
                            --do.pl('res(null)='||buf);
                            column_val(i) := buf;
                        ELSE
                            -- if object is unknown or does not exist add new element of type null
                            buf := NULL;
                            --do.pl('res(unknown)='||buf);
                            column_val(i) := buf;
                    END CASE;
                    IF i = column_paths.last THEN
                        outset.addinstance;
                        outset.piecewise();
                        FOR j IN column_val.first .. column_val.last LOOP
                            outset.setvarchar2(column_val(j));
                        END LOOP;
                        num_rows := num_rows + 1;
                    END IF;
                END LOOP row_loop_nested;
            END LOOP main_loop_nested;
        
            outset.endcreate;
        END IF;
    
        RETURN odciconst.success;
    END;

    MEMBER FUNCTION odcitableclose(SELF IN pljson_table_impl) RETURN NUMBER IS
    BEGIN
        RETURN odciconst.success;
    END;

END;
/
