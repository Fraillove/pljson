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

