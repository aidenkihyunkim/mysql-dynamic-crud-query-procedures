# MySQL Stored Procedure for CRUD Dynamic Queries

These are MySQL stored procedures that execute **CRUD dynamic queries** using JSON parameters

These procedures execute CRUD queries using JSON-formatted parameters, so that it becomes an interface between the application and the database.
If the schema or business logic changed, it can be applied without modification of programming.

- MySQL requirement : Version >= **5.7.9**
- [Sample of Condition Parameter](Condition_Samples.md)

# Stored Procedures & Functions

- [**sp_json_insert_table**](#INSERT-:-sp_json_insert_table) : Execute insert query
- [**sp_json_select_table**](#SELECT-:-sp_json_select_table) : Execute select query
- [**sp_json_update_table**](#UPDATE-:-sp_json_update_table) : Execute update query
- [**sp_json_delete_table**](#DELETE-:-sp_json_delete_table) : Execute delete query
- **sp_json_get_query_conditions** : Parsing query conditions from JSON
- **fn_get_json_query_conditions** : Parsing query conditions from JSON (subroutine of sp_json_get_query_conditions)
- **fn_get_json_query_page_conditions** : Parsing paging query conditions from JSON
- **fn_get_json_query_sort_conditions** : Parsing sorting query conditions from JSON
- **fn_get_json_query_table_column_map** :Getting table columns information from INFORMATION_SCHEMA

## INSERT : sp_json_insert_table

Order | Parameter | In/Out | Type | Description
------|-----------|--------|------|------------
1 | i_table | In | VARCHAR(64) | Table name
2 | i_columns | In | JSON | Columns data
3 | i_schema | In | VARCHAR(64) | Database name ( Optional, Default: DATABASE() )
4 | o_return | Out | INT | Return code ( 0: Success )
5 | o_row_count | Out | INT | Value of ROW_COUNT()
6 | o_last_insert_id | Out | BIGINT | Value of LAST_INSERT_ID()
```sql
CALL sp_json_insert_table( 'table',
    '{"col1_name":col1_value, "col2_name":"col2_value", "col3_name":"col3_value", ... }',
    'database', @return, @row_count, @last_insert_id );
```

## SELECT : sp_json_select_table

Order | Parameter | In/Out | Type | Description
------|-----------|--------|------|------------
1 | i_table | In | VARCHAR(64) | Table name
2 | [i_conditions](Condition_Samples.md) | In | JSON | Column search conditions
3 | i_schema | In | VARCHAR(64) | Database name ( Optional, Default: DATABASE() )
4 | o_return | Out | INT | Return code ( 0: Success )
5 | o_row_count | Out | INT | Value of FOUND_ROWS() ( On SQL_CALC_FOUND_ROWS  option )
```sql
CALL sp_json_select_table( 'table',
    '{"col1_name":col1_value, "col2_name":"col2_value", "col3_name":"col3_value", ... }',
    'database', @return, @row_count );
```

## UPDATE : sp_json_update_table

Order | Parameter | In/Out | Type | Description
------|-----------|--------|------|------------
1 | i_table | In | VARCHAR(64) | Table name
2 | i_columns | In | JSON | Columns data to update
3 | [i_conditions](Condition_Samples.md) | In | JSON | Column search conditions
4 | i_schema | In | VARCHAR(64) | Database name ( Optional, Default: DATABASE() )
5 | o_return | Out | INT | Return code ( 0: Success )
6 | o_row_count | Out | INT | Value of ROW_COUNT()
```sql
CALL sp_json_update_table( 'table',
    '{"col3_name":col3_value, "col4_name":"col4_value", "col5_name":"col5_value", ... }',
    '{"col1_name":col1_value, "col2_name":"col2_value", ... }',
    'database', @return, @row_count );
```

## DELETE : sp_json_delete_table

Order | Parameter | In/Out | Type | Description
------|-----------|--------|------|------------
1 | i_table | In | VARCHAR(64) | Table name
2 | [i_conditions](Condition_Samples.md) | In | JSON | Column search conditions
3 | i_schema | In | VARCHAR(64) | Database name ( Optional, Default: DATABASE() )
4 | o_return | Out | INT | Return code ( 0: Success )
5 | o_row_count | Out | INT | Value of ROW_COUNT()
```sql
CALL sp_json_delete_table( 'table',
    '{"col1_name":col1_value, "col2_name":"col2_value", "col3_name":"col3_value", ... }',
    'database', @return, @row_count );
```

## Return codes
- 0 : Success
- -101 ~ -10x : Internal error of making query
- -901 : Duplicate entry on primary key or unique key (MySQL Error 1062)
- -902 : Cannot add or update a child row: a foreign key constraint fails (MySQL Error 1216,1452)
- -903 : Cannot delete or update a parent row: a foreign key constraint fails (MySQL Error 1217,1451)
- -999 : Another errors (MySQL SQLEXCEPTION)


## Transaction processing
- Transaction processing is applied differently depending on the environment in which these procedures are executed.
- When these procedures are executed with the transaction started from the outside, COMMIT / ROLLBACK processing is not executed within procedures.
- If these procedures executed without any external transaction, COMMIT or ROLLBACK processing is executed inside procedures.


## License

MIT License (MIT)
