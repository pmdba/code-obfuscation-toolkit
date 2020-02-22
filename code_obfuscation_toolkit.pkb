CREATE OR REPLACE PACKAGE BODY code_obfuscation_toolkit
AS
    /******************************************************************************

        Name: code_obfuscation_toolkit
        Purpose:

        The code_obfuscation_toolkit package allows you to obfuscate the source code  
        of a variety of stored programs, including procedures, functions, package
        bodies, and type bodies. When wrapping an object, to further obfuscate the 
        original code in the event that it is ever unwrapped, all comments and line 
        breaks can also be removed by setting the p_Obfuscate flag to 'Y'.

        Objects can be wrapped individually, by type within a schema, or by schema.

        Revisions:
        Ver  Date         Author      Description
        ===  ===========  ==========  ========================================
        1.0  02-JAN-2019  pmdba       Oiginal Release

    ******************************************************************************/

    /* Remove comments and line breaks from code */
    FUNCTION strip_object (p_Clob IN CLOB)
        RETURN CLOB
    AS
        l_Clob   CLOB;
    BEGIN
        /* Remove comments defined by "/*" or "--" */
        l_Clob :=
            REGEXP_REPLACE (
                p_Clob,
                   '/\*([^*]|['
                || CHR (13)
                || CHR (10)
                || ']|(\*+([^*/]|['
                || CHR (13)
                || CHR (10)
                || '])))*\*+/|--.+|--+');

        /* Condense white spaces and line breaks to single spaces */
        l_Clob :=
            REGEXP_REPLACE (l_Clob,
                            '(\s*)([' || CHR (13) || CHR (10) || ']+?)(\s*)',
                            ' ');                                --||'[ ]*?');

        /* Return modified CLOB object */
        RETURN l_Clob;
    END strip_object;

    PROCEDURE wrap_object (p_ObjectOwner   IN VARCHAR2,
                           p_ObjectName    IN VARCHAR2,
                           p_ObjectType    IN VARCHAR2,
                           p_Obfuscate     IN VARCHAR2 DEFAULT 'Y')
    AS
        l_ObjectType       VARCHAR2(30);
        l_DDL              CLOB;
        l_DDLLength        NUMBER;
        l_Source           SYS.DBMS_SQL.VARCHAR2A;
        l_SourceLength     NUMBER;

        WRAPPING_SELF      EXCEPTION;
        PRAGMA EXCEPTION_INIT (WRAPPING_SELF, -24230);
        
        COMPILATION_ERROR  EXCEPTION;
        PRAGMA EXCEPTION_INIT (COMPILATION_ERROR, -24344);
        
        OBJECT_NOT_FOUND   EXCEPTION;
        PRAGMA EXCEPTION_INIT (OBJECT_NOT_FOUND, -31603);
    BEGIN
        DBMS_OUTPUT.ENABLE;
        DBMS_OUTPUT.PUT ( rpad(p_objecttype,13,' ') || ' :: ' || rpad(p_objectowner ||'.'|| p_objectname,length(p_objectowner)+31,' ') );
        
        /* Evaluate input parameters */
        CASE
            /* If ObjectType is invalid, raise an error */
            WHEN UPPER (p_ObjectType) NOT IN ('FUNCTION',
                                              'PACKAGE BODY',
                                              'PROCEDURE',
                                              'TYPE BODY')
            THEN
                RAISE_APPLICATION_ERROR (
                    -20001,
                    'The Object Type specified must be: ''FUNCTION'', ''PACKAGE BODY'', ''PROCEDURE'', or ''TYPE BODY''');
            /* If inputs are good, proceed with obfuscation */
            ELSE
                /* Generate object DDL from data dictionary */
                l_ObjectType := REPLACE(p_ObjectType,' ','_');
                
                l_DDL :=
                    SYS.DBMS_METADATA.GET_DDL (UPPER (l_ObjectType),
                                               UPPER (p_ObjectName),
                                               UPPER (p_ObjectOwner));

                IF INSTR (l_DDL, ' EDITIONABLE ') > 0
                THEN
                    l_DDL := REPLACE(l_DDL, 'EDITIONABLE ', '');
                END IF;
                
                /* If object is already wrapped, write message and skip it */
                CASE
                WHEN INSTR (l_DDL, '" wrapped ' || CHR (10)) > 0
                THEN
                    DBMS_OUTPUT.PUT_LINE (' :: Already wrapped');

                /* If object is not wrapped, generate DDL and wrap it */
                ELSE
                
                /* Remove comments, line breaks, and white space */
                IF UPPER (p_Obfuscate) = 'Y'
                THEN
                    l_DDL := strip_object (l_DDL);
                END IF;

                l_DDLLength := SYS.DBMS_LOB.GETLENGTH (l_DDL);

                /* Rebuild DDL CLOB as DBMS_SQL.VARCHAR2A array */
                l_Source.DELETE;
                l_SourceLength := 0;

                LOOP
                    EXIT WHEN (l_SourceLength >= l_DDLLength);
                    l_Source (l_Source.COUNT + 1) :=
                        SYS.DBMS_LOB.SUBSTR (l_DDL,
                                             32767,
                                             l_SourceLength + 1);
                    l_SourceLength :=
                        l_SourceLength + LENGTH (l_Source (l_Source.COUNT));
                END LOOP;

                /* Re-create wrapped object from source */
                SYS.DBMS_DDL.CREATE_WRAPPED (ddl => l_Source, lb => 1, ub => l_Source.COUNT);
                DBMS_OUTPUT.PUT_LINE (' :: Wrapped successfully');
            END CASE;
        END CASE;
    EXCEPTION
        /* If trying to wrap self, move on to next object */
        WHEN WRAPPING_SELF
        THEN
            DBMS_OUTPUT.PUT_LINE (' :: ORA-24230 - Cannot wrap self');
 
        /* If compilation error of target object, report and move on */
        WHEN COMPILATION_ERROR
        THEN
            DBMS_OUTPUT.PUT_LINE (' :: ORA-24344 - Compilation error');
            
        /* When the target object is not found, raise an error */
        WHEN OBJECT_NOT_FOUND
        THEN
            DBMS_OUTPUT.PUT_LINE (' :: ORA-31603 - Object not found');
            RAISE_APPLICATION_ERROR (
                -20002,
                   'The '
                || UPPER (p_ObjectType)
                || ' '
                || UPPER (p_ObjectOwner)
                || '.'
                || UPPER (p_ObjectName)
                || ' was not found.');
    END wrap_object;

    PROCEDURE wrap_object_type (p_ObjectOwner   IN VARCHAR2,
                                p_ObjectType    IN VARCHAR2,
                                p_Obfuscate     IN VARCHAR2 DEFAULT 'Y')
    AS
        l_ObjectOwner   VARCHAR2 (32);
        l_ObjectName    VARCHAR2 (32);
        l_ObjectType    VARCHAR2 (32);


        CURSOR object_list (c_ObjectOwner   IN VARCHAR2,
                            c_ObjectType    IN VARCHAR2)
        IS
            SELECT object_name
              FROM all_objects
             WHERE owner = c_ObjectOwner 
               AND status = 'VALID'
               AND object_type = c_ObjectType;
    BEGIN
        l_ObjectOwner := UPPER (p_ObjectOwner);
        l_ObjectType := UPPER (p_ObjectType);

        /* Evaluate input parameters */
        CASE
            /* If ObjectType is invalid, raise an error */
            WHEN l_ObjectType NOT IN ('FUNCTION',
                                      'PACKAGE BODY',
                                      'PROCEDURE',
                                      'TYPE BODY')
            THEN
                RAISE_APPLICATION_ERROR (
                    -20001,
                    'The Object Type specified must be: ''FUNCTION'', ''PACKAGE BODY'', ''PROCEDURE'', or ''TYPE BODY''');
            /* If inputs are good, proceed with obfuscation */
            ELSE
                OPEN object_list (l_ObjectOwner, l_ObjectType);

                IF object_list%NOTFOUND = TRUE
                THEN
                    raise_application_error (
                        -20006,
                           'Object owner '
                        || p_ObjectOwner
                        || ' does not exist or does not own any objects of type '
                        || p_ObjectType
                        || '.');
                ELSE
                    LOOP
                        FETCH object_list INTO l_ObjectName;

                        EXIT WHEN object_list%NOTFOUND;
                        wrap_object (l_ObjectOwner,
                                     l_ObjectName,
                                     l_ObjectType,
                                     p_Obfuscate);
                    END LOOP;
                END IF;

                CLOSE object_list;
        END CASE;
    END wrap_object_type;

    PROCEDURE wrap_schema (p_ObjectOwner   IN VARCHAR2,
                           p_Obfuscate     IN VARCHAR2 DEFAULT 'Y')
    AS
        l_ObjectOwner   VARCHAR2 (32);
        l_ObjectName    VARCHAR2 (32);
        l_ObjectType    VARCHAR2 (32);

        CURSOR object_list (c_ObjectOwner IN VARCHAR2)
        IS
            SELECT object_name, object_type
              FROM all_objects
             WHERE     owner = c_ObjectOwner
                   AND status = 'VALID'
                   AND object_type IN ('FUNCTION',
                                       'PACKAGE BODY',
                                       'PROCEDURE',
                                       'TYPE BODY');
    BEGIN
        l_ObjectOwner := UPPER (p_ObjectOwner);

        OPEN object_list (l_ObjectOwner);

        IF object_list%NOTFOUND = TRUE
        THEN
            raise_application_error (
                -20005,
                   'Object owner '
                || p_ObjectOwner
                || ' does not exist or does not own any objects which can be obfuscated.');
        ELSE
            LOOP
                FETCH object_list INTO l_ObjectName, l_ObjectType;

                EXIT WHEN object_list%NOTFOUND;
                wrap_object (l_ObjectOwner,
                             l_ObjectName,
                             l_ObjectType,
                             p_Obfuscate);
            END LOOP;
        END IF;

        CLOSE object_list;
    END wrap_schema;

END code_obfuscation_toolkit;
/
