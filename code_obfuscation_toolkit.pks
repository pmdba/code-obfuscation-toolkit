CREATE OR REPLACE PACKAGE code_obfuscation_toolkit
    AUTHID CURRENT_USER
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
AS
    /* Remove comments and line breaks from code */
    FUNCTION strip_object (p_Clob IN CLOB)
        RETURN CLOB;

    /* Wrap an individual object */
    PROCEDURE wrap_object (p_ObjectOwner   IN VARCHAR2,
                           p_ObjectName    IN VARCHAR2,
                           p_ObjectType    IN VARCHAR2,
                           p_Obfuscate     IN VARCHAR2 DEFAULT 'Y');

    /* Wrap all objects of specified type in a schema */
    PROCEDURE wrap_object_type (p_ObjectOwner   IN VARCHAR2,
                                p_ObjectType    IN VARCHAR2,
                                p_Obfuscate     IN VARCHAR2 DEFAULT 'Y');

    /* Wrap all objects in a schema */
    PROCEDURE wrap_schema (p_ObjectOwner   IN VARCHAR2,
                           p_Obfuscate     IN VARCHAR2 DEFAULT 'Y');

    TYPE varchar2_table IS TABLE OF CLOB;                   --varchar2(32767);
END code_obfuscation_toolkit;
/
