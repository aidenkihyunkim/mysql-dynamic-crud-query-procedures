-- -----------------------------------------------------
-- procedure sp_json_delete_table
-- -----------------------------------------------------

DROP procedure IF EXISTS `sp_json_delete_table`;

DELIMITER $$
CREATE PROCEDURE `sp_json_delete_table`(
  IN   i_table       VARCHAR(64) CHARSET utf8mb4 COLLATE utf8mb4_bin,
  IN   i_conditions  JSON,
  IN   i_schema      VARCHAR(64) CHARSET utf8mb4 COLLATE utf8mb4_bin,
  OUT  o_return      INT,
  OUT  o_row_count   INT
)
body:BEGIN
/**
  General procedure for deleting table rows from JSON
  2018-10 Aiden Kihyun Kim
  
  Parameters
    IN   i_table       VARCHAR(64)  : Table name
    IN   i_conditions  JSON         : Search/Sort/Paging conditions, See below samples
    IN   i_schema      VARCHAR(64)  : Database name
    OUT  o_return      INT          : Return code (0=success)
    OUT  o_row_count   INT          : Value of ROW_COUNT()
  Parameter i_conditions samnles
    case 1 (Object will be 'AND' condition): 
      {"col1_name": "col1_value", "col9_name": col9_value}
      => WHERE col1_name = 'col1_value' AND col9_name = col9_value
    case 2 (Limit): 
      { "LIMIT": 1 } => LIMIT 1
    case 3 (Complex conditions): 
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
        { "LIMIT": 2 }
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
      LIMIT 2
**/
  
  DECLARE v_autocommit      BIT DEFAULT @@AUTOCOMMIT;
  DECLARE v_schema          VARCHAR(64) CHARSET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL;
  DECLARE v_column_map      JSON DEFAULT NULL;
  DECLARE q_condition       LONGTEXT CHARSET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL;
  DECLARE q_limit LONGTEXT  CHARSET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL;
  DECLARE require_rollback  CONDITION FOR SQLSTATE '45000';
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN
    SET o_return = -999, o_row_count = 0; IF (v_autocommit=1) AND (@@AUTOCOMMIT=0) THEN ROLLBACK; SET SESSION autocommit = 1; END IF;
  END;
  DECLARE EXIT HANDLER FOR 1062 BEGIN 
    SET o_return = -901, o_row_count = 0; IF (v_autocommit=1) AND (@@AUTOCOMMIT=0) THEN ROLLBACK; SET SESSION autocommit = 1; END IF;
  END;
  DECLARE EXIT HANDLER FOR 1216,1452 BEGIN 
    SET o_return = -902, o_row_count = 0; IF (v_autocommit=1) AND (@@AUTOCOMMIT=0) THEN ROLLBACK; SET SESSION autocommit = 1; END IF;
  END;
  DECLARE EXIT HANDLER FOR 1217,1451 BEGIN 
    SET o_return = -903, o_row_count = 0; IF (v_autocommit=1) AND (@@AUTOCOMMIT=0) THEN ROLLBACK; SET SESSION autocommit = 1; END IF;
  END;
  DECLARE EXIT HANDLER FOR require_rollback BEGIN
    IF (v_autocommit=1) AND (@@AUTOCOMMIT=0) THEN ROLLBACK; SET SESSION autocommit = 1; END IF;
  END;
  
  SET o_return = -1, o_row_count = 0;
  
  SET v_schema = IF(i_schema IS NULL, DATABASE(), v_schema);
  SET v_column_map = fn_get_json_query_table_column_map(i_table, v_schema);

  CALL sp_json_get_query_conditions(v_column_map, i_conditions, 0, q_condition);
  SET q_limit = fn_get_json_query_page_conditions(i_conditions, 0);

  IF (q_condition IS NULL) THEN
    SET o_return = -101, o_row_count = 0;
    SIGNAL require_rollback;
  END IF;

  IF (v_autocommit = 1) THEN
    SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
    SET SESSION autocommit = 0;
    START TRANSACTION;
  END IF;

  SET @query = CONCAT('DELETE FROM `', v_schema, '`.`', i_table, '` WHERE ', q_condition);
  IF ((q_limit IS NOT NULL) AND (LENGTH(q_limit) > 0)) THEN
    SET @query = CONCAT(@query, ' LIMIT ', q_limit);
  END IF;  
  -- SELECT @query;

  PREPARE stmt FROM @query;
  EXECUTE stmt;
  SELECT ROW_COUNT() INTO @row_count;
  DEALLOCATE PREPARE stmt;

  IF (v_autocommit = 1) AND (@@AUTOCOMMIT = 0) THEN
    COMMIT;
    SET SESSION autocommit = 1;
  END IF;

  SET o_return = 0, o_row_count = @row_count;

END$$

DELIMITER ;