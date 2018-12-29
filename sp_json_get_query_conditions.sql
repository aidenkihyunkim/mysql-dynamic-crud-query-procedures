-- -----------------------------------------------------
-- procedure sp_json_get_query_conditions
-- -----------------------------------------------------

DROP procedure IF EXISTS `sp_json_get_query_conditions`;

DELIMITER $$
CREATE PROCEDURE `sp_json_get_query_conditions`(
  IN  i_column_map  JSON,
  IN  i_conditions  JSON,
  IN  i_depth       TINYINT,
  OUT o_conditions  LONGTEXT CHARSET utf8mb4 COLLATE utf8mb4_bin
)
body:BEGIN
/**
  Parsing query conditions from JSON
  2018-10 Aiden Kihyun Kim
**/

  DECLARE v_max_sp_recursion_depth  INT DEFAULT 0;
  DECLARE v_cnt1    INT DEFAULT 0;
  DECLARE v_cnt2    INT DEFAULT 0;
  DECLARE v_column  VARCHAR(64) CHARSET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL;
  DECLARE v_type    VARCHAR(64) CHARSET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL;
  DECLARE v_array   JSON DEFAULT NULL;
  
  SET v_max_sp_recursion_depth = @@max_sp_recursion_depth;
  IF (v_max_sp_recursion_depth < 100) THEN
    SET @@max_sp_recursion_depth = 100;
  END IF;

  SET o_conditions = '';
  
  IF JSON_VALID(i_conditions) THEN
  
    SET v_type = JSON_TYPE(i_conditions);
    IF (JSON_TYPE(i_conditions) = 'OBJECT') THEN
      SET o_conditions = fn_get_json_query_conditions(i_conditions, '', i_column_map);
      IF (LENGTH(o_conditions) > 0) THEN
        SET o_conditions = CONCAT('(', o_conditions, ')');
      END IF;

    ELSEIF (JSON_TYPE(i_conditions) = 'STRING') THEN
      SET o_conditions = CONCAT(o_conditions, ' ', JSON_UNQUOTE(i_conditions), ' ');

    ELSEIF (JSON_TYPE(i_conditions) = 'ARRAY') THEN
      SET o_conditions = CONCAT(o_conditions, IF(i_depth=0, '', '('));
      WHILE v_cnt1 < JSON_LENGTH(i_conditions) DO
        CALL sp_json_get_query_conditions(i_column_map, JSON_EXTRACT(i_conditions, CONCAT('$[',v_cnt1,']')), i_depth+1, @o_conditions);
        SET o_conditions = CONCAT(o_conditions,  @o_conditions);
        SET v_cnt1 = v_cnt1 + 1;
      END WHILE;  
      SET o_conditions = CONCAT(o_conditions, IF(i_depth=0, '', ')'));
    END IF;  
  END IF;

  SET @@max_sp_recursion_depth = v_max_sp_recursion_depth;
  
END$$

DELIMITER ;