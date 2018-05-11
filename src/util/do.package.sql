CREATE OR REPLACE PACKAGE do IS
    ENABLE BOOLEAN := TRUE;

    PROCEDURE pl
    (
        date_in IN DATE,
        mask_in IN VARCHAR2 := 'yyyy"年"mm"月"dd"日"hh24"时"mi"分"ss"秒" PM'
    );

    PROCEDURE pl(number_in IN NUMBER);

    PROCEDURE pl
    (
        char_in  IN VARCHAR2,
        split_in IN POSITIVE DEFAULT 255
    );

    PROCEDURE pl
    (
        char1_in IN VARCHAR2,
        char2_in IN VARCHAR2
    );

    PROCEDURE pl
    (
        char_in IN VARCHAR2,
        date_in IN DATE,
        mask_in IN VARCHAR2 := 'yyyy-mm-dd hh24:mi:ss'
    );

    PROCEDURE pl(boolean_in IN BOOLEAN);

    PROCEDURE pl
    (
        char_in    IN VARCHAR2,
        boolean_in IN BOOLEAN
    );

    PROCEDURE pl(xml_in IN sys.xmltype);

END do;

/*
BEGIN
    do.pl(DATE '2018-01-01');
    do.pl(1);
    do.pl('春眠不觉晓处处蚊子咬', 5);
    do.pl('hello', 'world');
    do.pl('时间', SYSDATE);
    do.pl(1 != 1);
    do.pl('is this right ?', 1 < 2);
    do.pl(sys.xmltype.createxml('<name><a id="1" value="some values">dummy</a></name>'));
END;
   do.enable := FALSE;  -- it will disable the output
*/


CREATE OR REPLACE PACKAGE BODY do IS
    -- Private

    PROCEDURE display_line(line_in IN VARCHAR2) IS
    BEGIN
        IF enable THEN
            dbms_output.put_line(line_in);
        END IF;
    END;

    FUNCTION boolean_string
    (
        boolean_in IN BOOLEAN,
        char_in    IN VARCHAR2 := NULL
    ) RETURN VARCHAR2 IS
    BEGIN

        IF boolean_in THEN
            RETURN char_in || ' ' || 'TRUE';
        ELSE
            RETURN char_in || ' ' || 'FALSE';
        END IF;

    END;

    -- Public

    PROCEDURE pl
    (
        date_in IN DATE,
        mask_in IN VARCHAR2 := 'yyyy"年"mm"月"dd"日"hh24"时"mi"分"ss"秒" PM'
    ) IS
    BEGIN

        display_line(to_char(date_in, mask_in));

    END;

    PROCEDURE pl(number_in IN NUMBER) IS
    BEGIN

        display_line(number_in);

    END;

    PROCEDURE pl
    (
        char_in  IN VARCHAR2,
        split_in IN POSITIVE DEFAULT 255
    ) IS
    BEGIN
        IF char_in IS NULL THEN
            display_line(char_in);
            RETURN;
        END IF;
        FOR i IN 1 .. ceil(length(char_in) / split_in) LOOP
            display_line(substr(char_in, split_in * (i - 1) + 1, split_in));
        END LOOP;

    END;

    PROCEDURE pl
    (
        char1_in IN VARCHAR2,
        char2_in IN VARCHAR2
    ) IS
    BEGIN

        display_line(char1_in || ': ' || char2_in);

    END;

    PROCEDURE pl
    (
        char_in IN VARCHAR2,
        date_in IN DATE,
        mask_in IN VARCHAR2 := 'yyyy-mm-dd hh24:mi:ss'
    ) IS
    BEGIN

        display_line(char_in || ': ' || to_char(date_in, mask_in));

    END;

    PROCEDURE pl(boolean_in IN BOOLEAN) IS
    BEGIN

        display_line(boolean_string(boolean_in));

    END;

    PROCEDURE pl
    (
        char_in    IN VARCHAR2,
        boolean_in IN BOOLEAN
    ) IS
    BEGIN

        display_line(boolean_string(boolean_in, char_in));

    END;

    PROCEDURE pl(xml_in IN sys.xmltype) IS
    BEGIN

        display_line(xml_in.getstringval());

    END;
BEGIN
  dbms_output.enable(NULL);
END do;

