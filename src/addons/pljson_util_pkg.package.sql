set define off

CREATE OR REPLACE PACKAGE pljson_util_pkg AUTHID CURRENT_USER AS

    -- generate JSON from REF Cursor
    FUNCTION ref_cursor_to_jsonlist
    (
        p_ref_cursor IN SYS_REFCURSOR,
        p_max_rows   IN NUMBER := NULL,
        p_skip_rows  IN NUMBER := NULL
    ) RETURN pljson_list;

    FUNCTION ref_cursor_to_jsonclob
    (
        p_ref_cursor IN SYS_REFCURSOR,
        p_max_rows   IN NUMBER := NULL,
        p_skip_rows  IN NUMBER := NULL
    ) RETURN CLOB;

    -- generate JSON from SQL statement
    FUNCTION sql_to_jsonlist
    (
        p_sql       IN VARCHAR2,
        p_max_rows  IN NUMBER := NULL,
        p_skip_rows IN NUMBER := NULL
    ) RETURN pljson_list;

    FUNCTION sql_to_jsonclob
    (
        p_sql       IN VARCHAR2,
        p_max_rows  IN NUMBER := NULL,
        p_skip_rows IN NUMBER := NULL
    ) RETURN CLOB;

END pljson_util_pkg;

/

CREATE OR REPLACE PACKAGE BODY pljson_util_pkg AS
    scanner_exception EXCEPTION;
    PRAGMA EXCEPTION_INIT(scanner_exception, -20100);
    parser_exception EXCEPTION;
    PRAGMA EXCEPTION_INIT(parser_exception, -20101);

    g_json_null_object CONSTANT VARCHAR2(20) := '{ }';

    FUNCTION get_xml_to_json_stylesheet RETURN VARCHAR2 AS
    BEGIN
        RETURN q'^<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
 <xsl:output indent="no" omit-xml-declaration="yes" method="text" encoding="UTF-8" media-type="text/x-json"/>
        <xsl:strip-space elements="*"/>
  <!--contant-->
  <xsl:variable name="d">0123456789</xsl:variable>

  <!-- ignore document text -->
  <xsl:template match="text()[preceding-sibling::node() or following-sibling::node()]"/>

  <!-- string -->
  <xsl:template match="text()">
    <xsl:call-template name="escape-string">
      <xsl:with-param name="s" select="."/>
    </xsl:call-template>
  </xsl:template>

  <!-- Main template for escaping strings; used by above template and for object-properties
       Responsibilities: placed quotes around string, and chain up to next filter, escape-bs-string -->
  <xsl:template name="escape-string">
    <xsl:param name="s"/>
    <xsl:text>"</xsl:text>
    <xsl:call-template name="escape-bs-string">
      <xsl:with-param name="s" select="$s"/>
    </xsl:call-template>
    <xsl:text>"</xsl:text>
  </xsl:template>

  <!-- Escape the backslash (\) before everything else. -->
  <xsl:template name="escape-bs-string">
    <xsl:param name="s"/>
    <xsl:choose>
      <xsl:when test="contains($s,'\')">
        <xsl:call-template name="escape-quot-string">
          <xsl:with-param name="s" select="concat(substring-before($s,'\'),'\\')"/>
        </xsl:call-template>
        <xsl:call-template name="escape-bs-string">
          <xsl:with-param name="s" select="substring-after($s,'\')"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:call-template name="escape-quot-string">
          <xsl:with-param name="s" select="$s"/>
        </xsl:call-template>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Escape the double quote ("). -->
  <xsl:template name="escape-quot-string">
    <xsl:param name="s"/>
    <xsl:choose>
      <xsl:when test="contains($s,'&quot;')">
        <xsl:call-template name="encode-string">
          <xsl:with-param name="s" select="concat(substring-before($s,'&quot;'),'\&quot;')"/>
        </xsl:call-template>
        <xsl:call-template name="escape-quot-string">
          <xsl:with-param name="s" select="substring-after($s,'&quot;')"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:call-template name="encode-string">
          <xsl:with-param name="s" select="$s"/>
        </xsl:call-template>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Replace tab, line feed and/or carriage return by its matching escape code. Can't escape backslash
       or double quote here, because they don't replace characters (&#x0; becomes \t), but they prefix
       characters (\ becomes \\). Besides, backslash should be seperate anyway, because it should be
       processed first. This function can't do that. -->
  <xsl:template name="encode-string">
    <xsl:param name="s"/>
    <xsl:choose>
      <!-- tab -->
      <xsl:when test="contains($s,'&#x9;')">
        <xsl:call-template name="encode-string">
          <xsl:with-param name="s" select="concat(substring-before($s,'&#x9;'),'\t',substring-after($s,'&#x9;'))"/>
        </xsl:call-template>
      </xsl:when>
      <!-- line feed -->
      <xsl:when test="contains($s,'&#xA;')">
        <xsl:call-template name="encode-string">
          <xsl:with-param name="s" select="concat(substring-before($s,'&#xA;'),'\n',substring-after($s,'&#xA;'))"/>
        </xsl:call-template>
      </xsl:when>
      <!-- carriage return -->
      <xsl:when test="contains($s,'&#xD;')">
        <xsl:call-template name="encode-string">
          <xsl:with-param name="s" select="concat(substring-before($s,'&#xD;'),'\r',substring-after($s,'&#xD;'))"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise><xsl:value-of select="$s"/></xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- number (no support for javascript mantissa) -->
  <xsl:template match="text()[not(string(number())='NaN' or
                      (starts-with(.,'0' ) and . != '0' and
not(starts-with(.,'0.' ))) or
                      (starts-with(.,'-0' ) and . != '-0' and
not(starts-with(.,'-0.' )))
                      )]">
    <xsl:value-of select="."/>
  </xsl:template>

  <!-- boolean, case-insensitive -->
  <xsl:template match="text()[translate(.,'TRUE','true')='true']">true</xsl:template>
  <xsl:template match="text()[translate(.,'FALSE','false')='false']">false</xsl:template>

  <!-- object -->
  <xsl:template match="*" name="base">
    <xsl:if test="not(preceding-sibling::*)">{</xsl:if>
    <xsl:call-template name="escape-string">
      <xsl:with-param name="s" select="name()"/>
    </xsl:call-template>
    <xsl:text>:</xsl:text>
    <!-- check type of node -->
    <xsl:choose>
      <!-- null nodes -->
      <xsl:when test="count(child::node())=0">null</xsl:when>
      <!-- other nodes -->
      <xsl:otherwise>
        <xsl:apply-templates select="child::node()"/>
      </xsl:otherwise>
    </xsl:choose>
    <!-- end of type check -->
    <xsl:if test="following-sibling::*">,</xsl:if>
    <xsl:if test="not(following-sibling::*)">}</xsl:if>
  </xsl:template>

  <!-- array -->
  <xsl:template match="*[count(../*[name(../*)=name(.)])=count(../*) and count(../*)&gt;1]">
    <xsl:if test="not(preceding-sibling::*)">[</xsl:if>
    <xsl:choose>
      <xsl:when test="not(child::node())">
        <xsl:text>null</xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates select="child::node()"/>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:if test="following-sibling::*">,</xsl:if>
    <xsl:if test="not(following-sibling::*)">]</xsl:if>
  </xsl:template>

  <!-- convert root element to an anonymous container -->
  <xsl:template match="/">
    <xsl:apply-templates select="node()"/>
  </xsl:template>

</xsl:stylesheet>^';
    
    END get_xml_to_json_stylesheet;

    FUNCTION ref_cursor_to_jsonlist
    (
        p_ref_cursor IN SYS_REFCURSOR,
        p_max_rows   IN NUMBER := NULL,
        p_skip_rows  IN NUMBER := NULL
    ) RETURN pljson_list AS
        l_num_rows    PLS_INTEGER;
        l_returnvalue CLOB;
    BEGIN
    
        l_returnvalue := ref_cursor_to_jsonclob(ref_cursor_to_jsonlist.p_ref_cursor,
                                                ref_cursor_to_jsonlist.p_max_rows,
                                                ref_cursor_to_jsonlist.p_skip_rows);
    
        IF (l_num_rows = 0) THEN
            RETURN pljson_list();
        ELSE
            IF (l_num_rows = 1) THEN
                DECLARE
                    ret pljson_list := pljson_list();
                BEGIN
                    ret.append(pljson(pljson(l_returnvalue).get('ROWSET'))
                               .get('ROW'));
                    RETURN ret;
                END;
            ELSE
                RETURN pljson_list(pljson(l_returnvalue).get('ROWSET'));
            END IF;
        END IF;
    
    EXCEPTION
        WHEN scanner_exception THEN
            dbms_output.put('Scanner problem with the following input: ');
            dbms_output.put_line(l_returnvalue);
            RAISE;
        WHEN parser_exception THEN
            dbms_output.put('Parser problem with the following input: ');
            dbms_output.put_line(l_returnvalue);
            RAISE;
        WHEN OTHERS THEN
            RAISE;
    END ref_cursor_to_jsonlist;

    FUNCTION ref_cursor_to_jsonclob
    (
        p_ref_cursor IN SYS_REFCURSOR,
        p_max_rows   IN NUMBER := NULL,
        p_skip_rows  IN NUMBER := NULL
    ) RETURN CLOB AS
        l_ctx         dbms_xmlgen.ctxhandle;
        l_num_rows    PLS_INTEGER;
        l_xml         xmltype;
        l_json        xmltype;
        l_returnvalue CLOB;
    BEGIN
    
        l_ctx := dbms_xmlgen.newcontext(p_ref_cursor);
    
        dbms_xmlgen.setnullhandling(l_ctx, dbms_xmlgen.empty_tag);
    
        -- for pagination
    
        IF p_max_rows IS NOT NULL THEN
            dbms_xmlgen.setmaxrows(l_ctx, p_max_rows);
        END IF;
    
        IF p_skip_rows IS NOT NULL THEN
            dbms_xmlgen.setskiprows(l_ctx, p_skip_rows);
        END IF;
    
        -- get the XML content
        l_xml := dbms_xmlgen.getxmltype(l_ctx, dbms_xmlgen.none);
    
        l_num_rows := dbms_xmlgen.getnumrowsprocessed(l_ctx);
    
        dbms_xmlgen.closecontext(l_ctx);
    
        CLOSE p_ref_cursor;
    
        IF l_num_rows > 0 THEN
            -- perform the XSL transformation
            l_json        := l_xml.transform(xmltype(get_xml_to_json_stylesheet));
            l_returnvalue := l_json.getclobval();
        ELSE
            l_returnvalue := g_json_null_object;
        END IF;
    
        l_returnvalue := dbms_xmlgen.convert(l_returnvalue,
                                             dbms_xmlgen.entity_decode);
    
        RETURN l_returnvalue;
    
    EXCEPTION
        WHEN scanner_exception THEN
            dbms_output.put('Scanner problem with the following input: ');
            dbms_output.put_line(l_returnvalue);
            RAISE;
        WHEN parser_exception THEN
            dbms_output.put('Parser problem with the following input: ');
            dbms_output.put_line(l_returnvalue);
            RAISE;
        WHEN OTHERS THEN
            RAISE;
    END ref_cursor_to_jsonclob;

    FUNCTION sql_to_jsonlist
    (
        p_sql       IN VARCHAR2,
        p_max_rows  IN NUMBER := NULL,
        p_skip_rows IN NUMBER := NULL
    ) RETURN pljson_list AS
        v_cur SYS_REFCURSOR;
    BEGIN
        OPEN v_cur FOR p_sql;
        RETURN ref_cursor_to_jsonlist(v_cur, p_max_rows, p_skip_rows);
    END sql_to_jsonlist;

    FUNCTION sql_to_jsonclob
    (
        p_sql       IN VARCHAR2,
        p_max_rows  IN NUMBER := NULL,
        p_skip_rows IN NUMBER := NULL
    ) RETURN CLOB AS
        v_cur SYS_REFCURSOR;
    BEGIN
        OPEN v_cur FOR p_sql;
        RETURN ref_cursor_to_jsonclob(v_cur, p_max_rows, p_skip_rows);
    
    END sql_to_jsonclob;

END pljson_util_pkg;
/
