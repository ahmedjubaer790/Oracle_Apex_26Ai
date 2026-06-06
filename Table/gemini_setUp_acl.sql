DECLARE
    l_apex_schema VARCHAR2(100);
BEGIN
    -- 1. Get your exact APEX schema name
    SELECT username INTO l_apex_schema
    FROM dba_users
    WHERE username LIKE 'APEX_%'
    AND username NOT LIKE '%_PUBLIC_USER%'
    ORDER BY username DESC
    FETCH FIRST 1 ROWS ONLY;

    DBMS_OUTPUT.PUT_LINE('Working with APEX Schema: ' || l_apex_schema);

    -- 2. Open access using a wildcard and NO specific port numbers
    -- This avoids the ORA-24244 validation error
    DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
        host       => '*.googleapis.com',
        ace        => xs$ace_type(privilege_list => xs$name_list('connect', 'resolve'),
                                  principal_name => l_apex_schema,
                                  principal_type => xs_acl.ptype_db));
                                  
    DBMS_OUTPUT.PUT_LINE('ACL Success: Google API access granted.');
END;
/
COMMIT;

show con_name;

BEGIN
    DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
        host => '*',
        ace  => xs$ace_type(privilege_list => xs$name_list('connect', 'resolve'),
                            principal_name => 'PUBLIC',
                            principal_type => xs_acl.ptype_db));
END;
/
COMMIT;