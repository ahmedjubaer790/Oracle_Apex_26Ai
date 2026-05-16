BEGIN
    DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
        host => 'api.cohere.ai',
        lower_port => 443,
        upper_port => 443,
        ace => xs$ace_type(
            privilege_list => xs$name_list('connect', 'resolve'),
            principal_name => 'APEX_260100',
            principal_type => xs_acl.ptype_db
        )
    );
    COMMIT;
END;
/

--2nd
BEGIN
    DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
        host => 'api.cohere.ai',
        lower_port => 443,
        upper_port => 443,
        ace => xs$ace_type(
            privilege_list => xs$name_list('connect', 'resolve'),
            principal_name => 'AI',
            principal_type => xs_acl.ptype_db
        )
    );
    COMMIT;
END;
/

--if port create the problem then use:
BEGIN
    DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
        host => 'api.cohere.ai',
        ace => xs$ace_type(
            privilege_list => xs$name_list('connect', 'resolve'),
            principal_name => 'APEX_260100',
            principal_type => xs_acl.ptype_db
        )
    );
    COMMIT;
END;
/

--and
BEGIN
    DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
        host => 'api.cohere.ai',
        ace => xs$ace_type(
            privilege_list => xs$name_list('connect', 'resolve'),
            principal_name => 'AI',
            principal_type => xs_acl.ptype_db
        )
    );
    COMMIT;
END;
/

--use new ai model
command-r-plus-08-2024
or command-a-03-2025
