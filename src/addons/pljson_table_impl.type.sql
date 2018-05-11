
create or replace type pljson_varray as table of varchar2(32767);
/

create or replace type pljson_vtab as table of pljson_varray;
/

create or replace type pljson_narray as table of number;
/

create synonym pljson_table for pljson_table_impl;

CREATE OR REPLACE TYPE pljson_table_impl AS OBJECT
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
