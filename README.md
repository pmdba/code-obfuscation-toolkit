# code-obfuscation-toolkit
The code_obfuscation_toolkit package allows you to obfuscate the source code of a variety of stored programs, including procedures, functions, package bodies, and type bodies. Objects can be wrapped individually, by object type within a schema, or across an entire schema with a single execution. When wrapping an object, to further obfuscate the original code in the event that it is ever unwrapped, all comments and line breaks can also be removed by setting the p_Obfuscate flag to 'Y'.

Before obfuscation:
<pre>
create or replace procedure comment_test as
/* 
   This is the first comment block
*/
begin
    --
    -- this is the second comment block
    --
    /* this is an inline comment */ null;
    null; -- this is a trailing comment
    /* this is the third comment block */
end;
</pre>
After obfuscation:
<pre>
CREATE OR REPLACE PROCEDURE "PMDBA"."COMMENT_TEST" as begin null; null; end;
</pre>
Objects can be wrapped individually, by type within a schema, or by schema.

Example:

<pre>
> set serveroutput on;

> exec code_obfuscation_toolkit.wrap_object ('PMDBA','COMMENT_TEST','FUNCTION','Y');

BEGIN code_obfuscation_toolkit.wrap_object ('PMDBA','COMMENT_TEST','FUNCTION','Y'); END;
Error report -
ORA-20002: The FUNCTION PMDBA.COMMENT_TEST was not found.
ORA-06512: at "PMDBA.CODE_OBFUSCATION_TOOLKIT", line 148
ORA-06512: at line 1

> exec code_obfuscation_toolkit.wrap_object_type ('PMDBA','PACKAGE BODY','Y');

PACKAGE BODY  :: PMDBA.CODE_OBFUSCATION_TOOLKIT       :: ORA-24230 - Cannot wrap self
PACKAGE BODY  :: PMDBA.UTL_PASSWORD                   :: Already wrapped

PL/SQL procedure successfully completed.

> exec code_obfuscation_toolkit.wrap_schema('PMDBA','Y');

PACKAGE BODY  :: PMDBA.CODE_OBFUSCATION_TOOLKIT       :: ORA-24230 - Cannot wrap self
PROCEDURE     :: PMDBA.COMMENT_TEST                   :: Wrapped successfully
PACKAGE BODY  :: PMDBA.UTL_PASSWORD                   :: Already wrapped

PL/SQL procedure successfully completed.
</pre>
