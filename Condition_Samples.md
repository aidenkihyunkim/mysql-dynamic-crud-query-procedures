# Sample of Condition Parameter

The following samples show the usage of **i_conditions** parameters of each procedure.

### Common objects are linked by AND
```json
{"col1_name": "col1_value", "col2_name": 123, "col3_name": "col3_value"}
```
:arrow_right:
```sql
WHERE col1_name = 'col1_value' AND col9_name = 123 AND col3_value = 'col3_value'
```

### Sorting (Allow at SELECT statement only)
- Simple
    - `{"_ORDER_BY": "col1_name"}` :arrow_right: `ORDER BY col1_name`
    - `{"_ORDER_BY": {"col1_name": "desc"}}` :arrow_right: `ORDER BY col1_name DESC`
    - `{"_ORDER_BY": [ "col1_name", {"col2_name": "desc"} ]}` :arrow_right: `ORDER BY col1_name, col2_name DESC`

### Limits (Allow at SELECT statement only)
- Limit
    - `{"_LIMIT_BY": 10}` :arrow_right: `LIMIT 10`
    - `{"_LIMIT_BY": [0, 10]}` :arrow_right: `LIMIT 0, 10`
- Paging
    - `{"_PAGE_BY": [2, 10]}` :arrow_right: `LIMIT 10, 10`
    - Format : `{"_PAGE_BY": [PAGE_NUMBER, PAGE_SIZE]}`
    - The `_PAGE_BY` item will be ignored if `_LIMIT_BY` and `_PAGE_BY` are present at the same conditions

### Complex conditions
```json
[
  {"col1_name": "col1_value", "col9_name": 123},
  "AND",
  [
    {"col2_name": "code"},
    "OR",
    {"col3_name": null},
    "OR",
    {"col3_name": ["<>", 20]},
    "OR",
    {"col3_name": [">", 20]},
    "OR",
    {"col3_name": ["<=", 100]},
    "OR",
    {"col3_name": ["BETWEEN", 20, 40]},
    "OR",
    {"col4_name": ["LIKE", "%res"]},
    "OR",
    {"col5_name": ["IN", [1,2,3]]},
    "OR",
    {"col5_name": ["NOT_IN", ["4","5","6"]]},
    "OR",
    {"col6_name": ["IS", null]},
    "OR",
    [
      {"col7_name": ["IS_NOT", null]},
      "AND",
      {"col8_name": ["MATCH", "abc"]}
    ]
  ],
  { "_ORDER_BY": [
    "col2_name",
    {"col3_name":"asc"}
  ]},        
  { "_PAGE_BY": [1, 10] }
]
```
:arrow_right:
```sql
WHERE
  (col1_name = 'col1_value' AND col9_name = 123)
  AND (
    (col2_name = 'code')
    OR (col3_name IS NULL)
    OR (col3_name <> 30)
    OR (col3_name > 20)
    OR (col3_name < 100)
    OR (col3_name BETWEEN 20 AND 40)
    OR (col4_name LIKE '%res')
    OR (col5_name IN (1,2,3))
    OR (col5_name NOT IN ('4','5','6'))
    OR (col6_name IS null)
    OR (
      (`col7_name` IS NOT null)
      AND (MATCH (col8_name) AGAINST ('"abc"' IN BOOLEAN MODE))
    )
  )
ORDER BY col2_name, col3_name ASC
LIMIT 0, 10
```
