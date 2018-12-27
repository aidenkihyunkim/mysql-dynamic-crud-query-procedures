-- -----------------------------------------------------
-- procedure sp_json_select_table
-- -----------------------------------------------------

DROP procedure IF EXISTS `sp_json_select_table`;

DELIMITER $$
CREATE PROCEDURE `sp_json_select_table`(
  IN   i_table       VARCHAR(64) CHARSET utf8mb4 COLLATE utf8mb4_bin,
  IN   i_conditions  JSON,
  IN   i_schema      VARCHAR(64) CHARSET utf8mb4 COLLATE utf8mb4_bin,
  OUT  o_return      INT,
  OUT  o_row_count   INT
)
body:BEGIN
/**
  General procedure for selecting table rows from JSON
  2018-10 Aiden Kihyun Kim
  
  Parameters
    IN   i_table       VARCHAR(64)  : Table name
    IN   i_conditions  JSON         : Search/Sort/Paging conditions, See below samples
    IN   i_schema      VARCHAR(64)  : Database name
    OUT  o_return      INT          : Return code (0=success)
    OUT  o_row_count   INT          : Value of FOUND_ROWS()
  Parameter i_conditions samnles
    case 1 (Object will be 'AND' condition): 
      {"col1_name": "col1_value", "col9_name": col9_value}
      => WHERE col1_name = 'col1_value' AND col9_name = col9_value
    case 2 (Sorting): 
      { "ORDER_BY": [ "col2_name", {"col3_name":"asc"} ] }
      => ORDER BY col2_name, col3_name ASC
    case 3 (Limit): 
      { "LIMIT": 10 } => LIMIT 10
      { "LIMIT": [0, 10] } => LIMIT 0, 10
    case 4 (Paging): 
      { "PAGE_BY": [1, 10] } => LIMIT 0, 10
      (*) Process 'LIMIT' only if 'LIMIT' and 'PAGE_BY' are present at the same conditions
    case 5 (Complex conditions): 
      [
        {"col1_name": "col1_value", "col9_name": col9_value},
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
        { "ORDER_BY": [
          col2_name",
          {"col3_name":"asc"}
        ]},        
        { "PAGE_BY": [1, 10] }
      ],
      =>
      WHERE
        (col1_name = 'col1_value' AND col9_name = col9_value)
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
      ORDER BY
        col2_name, col3_name ASC
      LIMIT 0, 10
**/  

  DECLARE v_rowcount     INT DEFAULT NULL;
  DECLARE v_schema       VARCHAR(64) CHARSET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL;
  DECLARE v_column_map   JSON DEFAULT NULL;
  DECLARE v_cnt          INT DEFAULT 0;  
  DECLARE v_column       VARCHAR(64) CHARSET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL;
  DECLARE v_column_type  VARCHAR(64) CHARSET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL;
  DECLARE q_column       LONGTEXT CHARSET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL;
  DECLARE q_condition    LONGTEXT CHARSET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL;
  DECLARE q_sorts        LONGTEXT CHARSET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL;
  DECLARE q_limit        LONGTEXT CHARSET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION SET o_return = -999, o_row_count = 0;
  
  SET o_return = -1, o_row_count = 0;

  SET v_schema = IF(i_schema IS NULL, DATABASE(), i_schema);
  SET v_column_map = fn_get_json_query_table_column_map(i_table, v_schema);

  -- Create column query string
  WHILE v_cnt < JSON_LENGTH(v_column_map) DO
    SET v_column = JSON_UNQUOTE(JSON_EXTRACT(JSON_KEYS(v_column_map), CONCAT('$[',v_cnt,']')));
    SET v_column_type = JSON_UNQUOTE(JSON_EXTRACT(v_column_map, CONCAT('$.',v_column)));
    
    SET q_column = IF(q_column IS NULL, '', CONCAT(q_column,', '));
    IF (v_column_type = 'json') THEN
      SET q_column = CONCAT(q_column, 'CAST(`', v_column, '` AS CHAR) AS ', v_column);
    ELSEIF (INSTR(v_column_type,'binary')>0) THEN
      SET q_column = CONCAT(q_column, 'HEX(`', v_column, '`) AS ', v_column);
    ELSEIF (INSTR(v_column_type,'point')>0 OR INSTR(v_column_type,'linestring')>0 OR INSTR(v_column_type,'polygon')>0 OR INSTR(v_column_type,'geometry')>0) THEN
      SET q_column = CONCAT(q_column, 'ST_AsText(`', v_column, '`) AS ', v_column);
    ELSE
      SET q_column = CONCAT(q_column, '`', v_column, '`');
    END IF;
    SET v_cnt = v_cnt + 1;
  END WHILE;
  
  CALL sp_json_get_query_conditions(v_column_map, i_conditions, 0, q_condition);
  SET q_sorts = fn_get_json_query_sort_conditions(i_conditions, v_column_map);
  SET q_limit = fn_get_json_query_page_conditions(i_conditions, 1);
  
  SET @query = CONCAT('SELECT SQL_CALC_FOUND_ROWS ', q_column, ' FROM `', v_schema, '`.`', i_table, '`');
  IF ((q_condition IS NOT NULL) AND (LENGTH(q_condition) > 0)) THEN
    SET @query = CONCAT(@query, ' WHERE ', q_condition);
  END IF;  
  IF ((q_sorts IS NOT NULL) AND (LENGTH(q_sorts) > 0)) THEN
    SET @query = CONCAT(@query, ' ORDER BY ', q_sorts);
  END IF;  
  IF ((q_limit IS NOT NULL) AND (LENGTH(q_limit) > 0)) THEN
    SET @query = CONCAT(@query, ' LIMIT ', q_limit);
  END IF;  
  -- SELECT @query;

  PREPARE stmt FROM @query;
  EXECUTE stmt;
  SELECT FOUND_ROWS() INTO @row_count;
  DEALLOCATE PREPARE stmt;
  
  SET o_return = 0, o_row_count = @row_count;
  
END$$

DELIMITER ;