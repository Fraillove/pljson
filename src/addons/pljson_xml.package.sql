set define off

CREATE OR REPLACE PACKAGE pljson_xml AS
    jsonml_stylesheet xmltype := NULL;

    FUNCTION xml2json(xml IN xmltype) RETURN pljson_list;
    FUNCTION xmlstr2json(xmlstr IN VARCHAR2) RETURN pljson_list;
    
    FUNCTION json2xml
    (
        obj     pljson,
        tagname VARCHAR2 DEFAULT 'root'
    ) RETURN xmltype;

END pljson_xml;
/


CREATE OR REPLACE PACKAGE BODY pljson_xml AS
    --private
    FUNCTION get_jsonml_stylesheet RETURN xmltype AS
    BEGIN
        IF (jsonml_stylesheet IS NULL) THEN
            jsonml_stylesheet := xmltype('<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
				xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

	<xsl:output method="text"
				media-type="application/json"
				encoding="UTF-8"
				indent="no"
				omit-xml-declaration="yes" />

	<!-- constants -->
	<xsl:variable name="XHTML"
				  select="''http://www.w3.org/1999/xhtml''" />

	<xsl:variable name="START_ELEM"
				  select="''[''" />

	<xsl:variable name="END_ELEM"
				  select="'']''" />

	<xsl:variable name="VALUE_DELIM"
				  select="'',''" />

	<xsl:variable name="START_ATTRIB"
				  select="''{''" />

	<xsl:variable name="END_ATTRIB"
				  select="''}''" />

	<xsl:variable name="NAME_DELIM"
				  select="'':''" />

	<xsl:variable name="STRING_DELIM"
				  select="''&#x22;''" />

	<xsl:variable name="START_COMMENT"
				  select="''/*''" />

	<xsl:variable name="END_COMMENT"
				  select="''*/''" />

	<!-- root-node -->
	<xsl:template match="/">
		<xsl:apply-templates select="*" />
	</xsl:template>

	<!-- comments -->
	<xsl:template match="comment()">
	<!-- uncomment to support JSON comments -->
	<!--
		<xsl:value-of select="$START_COMMENT" />

		<xsl:value-of select="."
					  disable-output-escaping="yes" />

		<xsl:value-of select="$END_COMMENT" />
	-->
	</xsl:template>

	<!-- elements -->
	<xsl:template match="*">
		<xsl:value-of select="$START_ELEM" />

		<!-- tag-name string -->
		<xsl:value-of select="$STRING_DELIM" />
		<xsl:choose>
			<xsl:when test="namespace-uri()=$XHTML">
				<xsl:value-of select="local-name()" />
			</xsl:when>
			<xsl:otherwise>
				<xsl:value-of select="name()" />
			</xsl:otherwise>
		</xsl:choose>
		<xsl:value-of select="$STRING_DELIM" />

		<!-- attribute object -->
		<xsl:if test="count(@*)>0">
			<xsl:value-of select="$VALUE_DELIM" />
			<xsl:value-of select="$START_ATTRIB" />
			<xsl:for-each select="@*">
				<xsl:if test="position()>1">
					<xsl:value-of select="$VALUE_DELIM" />
				</xsl:if>
				<xsl:apply-templates select="." />
			</xsl:for-each>
			<xsl:value-of select="$END_ATTRIB" />
		</xsl:if>

		<!-- child elements and text-nodes -->
		<xsl:for-each select="*|text()">
			<xsl:value-of select="$VALUE_DELIM" />
			<xsl:apply-templates select="." />
		</xsl:for-each>

		<xsl:value-of select="$END_ELEM" />
	</xsl:template>

	<!-- text-nodes -->
	<xsl:template match="text()">
		<xsl:call-template name="escape-string">
			<xsl:with-param name="value"
							select="." />
		</xsl:call-template>
	</xsl:template>

	<!-- attributes -->
	<xsl:template match="@*">
		<xsl:value-of select="$STRING_DELIM" />
		<xsl:choose>
			<xsl:when test="namespace-uri()=$XHTML">
				<xsl:value-of select="local-name()" />
			</xsl:when>
			<xsl:otherwise>
				<xsl:value-of select="name()" />
			</xsl:otherwise>
		</xsl:choose>
		<xsl:value-of select="$STRING_DELIM" />

		<xsl:value-of select="$NAME_DELIM" />

		<xsl:call-template name="escape-string">
			<xsl:with-param name="value"
							select="." />
		</xsl:call-template>

	</xsl:template>

	<!-- escape-string: quotes and escapes -->
	<xsl:template name="escape-string">
		<xsl:param name="value" />

		<xsl:value-of select="$STRING_DELIM" />

		<xsl:if test="string-length($value)>0">
			<xsl:variable name="escaped-whacks">
				<!-- escape backslashes -->
				<xsl:call-template name="string-replace">
					<xsl:with-param name="value"
									select="$value" />
					<xsl:with-param name="find"
									select="''\''" />
					<xsl:with-param name="replace"
									select="''\\''" />
				</xsl:call-template>
			</xsl:variable>

			<xsl:variable name="escaped-LF">
				<!-- escape line feeds -->
				<xsl:call-template name="string-replace">
					<xsl:with-param name="value"
									select="$escaped-whacks" />
					<xsl:with-param name="find"
									select="''&#x0A;''" />
					<xsl:with-param name="replace"
									select="''\n''" />
				</xsl:call-template>
			</xsl:variable>

			<xsl:variable name="escaped-CR">
				<!-- escape carriage returns -->
				<xsl:call-template name="string-replace">
					<xsl:with-param name="value"
									select="$escaped-LF" />
					<xsl:with-param name="find"
									select="''&#x0D;''" />
					<xsl:with-param name="replace"
									select="''\r''" />
				</xsl:call-template>
			</xsl:variable>

			<xsl:variable name="escaped-tabs">
				<!-- escape tabs -->
				<xsl:call-template name="string-replace">
					<xsl:with-param name="value"
									select="$escaped-CR" />
					<xsl:with-param name="find"
									select="''&#x09;''" />
					<xsl:with-param name="replace"
									select="''\t''" />
				</xsl:call-template>
			</xsl:variable>

			<!-- escape quotes -->
			<xsl:call-template name="string-replace">
				<xsl:with-param name="value"
								select="$escaped-tabs" />
				<xsl:with-param name="find"
								select="''&quot;''" />
				<xsl:with-param name="replace"
								select="''\&quot;''" />
			</xsl:call-template>
		</xsl:if>

		<xsl:value-of select="$STRING_DELIM" />
	</xsl:template>

	<!-- string-replace: replaces occurances of one string with another -->
	<xsl:template name="string-replace">
		<xsl:param name="value" />
		<xsl:param name="find" />
		<xsl:param name="replace" />

		<xsl:choose>
			<xsl:when test="contains($value,$find)">
				<!-- replace and call recursively on next -->
				<xsl:value-of select="substring-before($value,$find)"
							  disable-output-escaping="yes" />
				<xsl:value-of select="$replace"
							  disable-output-escaping="yes" />
				<xsl:call-template name="string-replace">
					<xsl:with-param name="value"
									select="substring-after($value,$find)" />
					<xsl:with-param name="find"
									select="$find" />
					<xsl:with-param name="replace"
									select="$replace" />
				</xsl:call-template>
			</xsl:when>
			<xsl:otherwise>
				<!-- no replacement necessary -->
				<xsl:value-of select="$value"
							  disable-output-escaping="yes" />
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>

</xsl:stylesheet>');
        END IF;
        RETURN jsonml_stylesheet;
    END get_jsonml_stylesheet;

    FUNCTION escapestr(str VARCHAR2) RETURN VARCHAR2 AS
        buf VARCHAR2(32767) := '';
        ch  VARCHAR2(4);
    BEGIN
        FOR i IN 1 .. length(str) LOOP
            ch := substr(str, i, 1);
            CASE ch
                WHEN '&' THEN
                    buf := buf || '&amp;';
                WHEN '<' THEN
                    buf := buf || '&lt;';
                WHEN '>' THEN
                    buf := buf || '&gt;';
                WHEN '"' THEN
                    buf := buf || '&quot;';
                ELSE
                    buf := buf || ch;
            END CASE;
        END LOOP;
        RETURN buf;
    END escapestr;

    /* Clob methods from printer */
    PROCEDURE add_to_clob
    (
        buf_lob IN OUT NOCOPY CLOB,
        buf_str IN OUT NOCOPY VARCHAR2,
        str     VARCHAR2
    ) AS
    BEGIN
        IF (length(str) > 32767 - length(buf_str)) THEN
            dbms_lob.append(buf_lob, buf_str);
            buf_str := str;
        ELSE
            buf_str := buf_str || str;
        END IF;
    END add_to_clob;

    PROCEDURE flush_clob
    (
        buf_lob IN OUT NOCOPY CLOB,
        buf_str IN OUT NOCOPY VARCHAR2
    ) AS
    BEGIN
        dbms_lob.append(buf_lob, buf_str);
    END flush_clob;

    PROCEDURE tostring
    (
        obj     pljson_value,
        tagname IN VARCHAR2,
        xmlstr  IN OUT NOCOPY CLOB,
        xmlbuf  IN OUT NOCOPY VARCHAR2
    ) AS
        v_obj  pljson;
        v_list pljson_list;
    
        v_keys  pljson_list;
        v_value pljson_value;
        key_str VARCHAR2(4000);
    BEGIN
        IF (obj.is_object()) THEN
            add_to_clob(xmlstr, xmlbuf, '<' || tagname || '>');
            v_obj := pljson(obj);
        
            v_keys := v_obj.get_keys();
            FOR i IN 1 .. v_keys.count LOOP
                v_value := v_obj.get(i);
                key_str := v_keys.get(i).str;
            
                IF (key_str = 'content') THEN
                    IF (v_value.is_array()) THEN
                        DECLARE
                            v_l pljson_list := pljson_list(v_value);
                        BEGIN
                            FOR j IN 1 .. v_l.count LOOP
                                IF (j > 1) THEN
                                    add_to_clob(xmlstr,
                                                xmlbuf,
                                                chr(13) || chr(10));
                                END IF;
                                add_to_clob(xmlstr,
                                            xmlbuf,
                                            escapestr(v_l.get(j).to_char()));
                            END LOOP;
                        END;
                    ELSE
                        add_to_clob(xmlstr,
                                    xmlbuf,
                                    escapestr(v_value.to_char()));
                    END IF;
                ELSIF (v_value.is_array()) THEN
                    DECLARE
                        v_l pljson_list := pljson_list(v_value);
                    BEGIN
                        FOR j IN 1 .. v_l.count LOOP
                            v_value := v_l.get(j);
                            IF (v_value.is_array()) THEN
                                add_to_clob(xmlstr,
                                            xmlbuf,
                                            '<' || key_str || '>');
                                add_to_clob(xmlstr,
                                            xmlbuf,
                                            escapestr(v_value.to_char()));
                                add_to_clob(xmlstr,
                                            xmlbuf,
                                            '</' || key_str || '>');
                            ELSE
                                tostring(v_value, key_str, xmlstr, xmlbuf);
                            END IF;
                        END LOOP;
                    END;
                ELSIF (v_value.is_null() OR
                      (v_value.is_string AND v_value.get_string IS NULL)) THEN
                    add_to_clob(xmlstr, xmlbuf, '<' || key_str || '/>');
                ELSE
                    tostring(v_value, key_str, xmlstr, xmlbuf);
                END IF;
            END LOOP;
        
            add_to_clob(xmlstr, xmlbuf, '</' || tagname || '>');
        ELSIF (obj.is_array()) THEN
            v_list := pljson_list(obj);
            FOR i IN 1 .. v_list.count LOOP
                v_value := v_list.get(i);
                tostring(v_value, nvl(tagname, 'array'), xmlstr, xmlbuf);
            END LOOP;
        ELSE
            add_to_clob(xmlstr,
                        xmlbuf,
                        '<' || tagname || '>' || CASE WHEN
                        obj.value_of() IS NOT NULL THEN
                        escapestr(obj.value_of())
                        END || '</' || tagname || '>');
        END IF;
    END tostring;

    FUNCTION json2xml
    (
        obj     pljson,
        tagname VARCHAR2 DEFAULT 'root'
    ) RETURN xmltype AS
        xmlstr      CLOB := empty_clob();
        xmlbuf      VARCHAR2(32767) := '';
        returnvalue xmltype;
    BEGIN
        dbms_lob.createtemporary(xmlstr, TRUE);
    
        tostring(obj.to_json_value(), tagname, xmlstr, xmlbuf);
    
        flush_clob(xmlstr, xmlbuf);
        returnvalue := xmltype('<?xml version="1.0"?>' || xmlstr);
        dbms_lob.freetemporary(xmlstr);
        RETURN returnvalue;
    END;

    FUNCTION xml2json(xml IN xmltype) RETURN pljson_list AS
        l_json        xmltype;
        l_returnvalue CLOB;
    BEGIN
        l_json        := xml.transform(get_jsonml_stylesheet);
        l_returnvalue := l_json.getclobval();
        l_returnvalue := dbms_xmlgen.convert(l_returnvalue,
                                             dbms_xmlgen.entity_decode);
        --do.pl(l_returnvalue);
        RETURN pljson_list(l_returnvalue);
    END xml2json;

    FUNCTION xmlstr2json(xmlstr IN VARCHAR2) RETURN pljson_list AS
    BEGIN
        RETURN xml2json(xmltype(xmlstr));
    END xmlstr2json;

END pljson_xml;
/
                                         

/*
DECLARE
    obj pljson := pljson('{a:1,b:[2,3,4],c:true}');
    x   xmltype;
BEGIN
    obj.print;
    x := pljson_xml.json2xml(obj);
    do.pl(x);
    pljson_xml.xml2json(xmltype('<?xml version="1.0" encoding="UTF-8" ?>
   <collection xmlns="">
     <record>
       <leader>-----nam0-22-----^^^450-</leader>
       <datafield tag="200" ind1="1" ind2=" ">
         <subfield code="a">Lebron</subfield>
         <subfield code="f">Love</subfield>
       </datafield>
       <datafield tag="209" ind1=" " ind2=" ">
         <subfield code="a">Harden</subfield>
         <subfield code="b">Paul</subfield>
         <subfield code="c">Durant</subfield>
         <subfield code="d">Curry</subfield>
       </datafield>
       <datafield tag="610" ind1="0" ind2=" ">
         <subfield code="a">Davis</subfield>
         <subfield code="a">Rondo</subfield>
       </datafield>
     </record>
   </collection>')).print();
END;
                                         
*/
