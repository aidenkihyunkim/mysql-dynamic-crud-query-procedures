-- -----------------------------------------------------
-- function fn_get_json_query_sort_conditions
-- -----------------------------------------------------

DROP function IF EXISTS `fn_get_json_query_sort_conditions`;

DELIMITER $$
CREATE FUNCTION `fn_get_json_query_sort_conditions`(
  i_conditions  JSON,
  i_column_map  JSON
) RETURNS       LONGTEXT CHARSET utf8mb4 COLLATE utf8mb4_bin
BEGIN
/**
  Parsing sorting query conditions from JSON
  2018-10 Aiden Kihyun Kim
**/

  DECLARE v_sort_column  VARCHAR(64) CHARSET utf8mb4 COLLATE utf8mb4_bin DEFAULT '_ORDER_BY';
  DECLARE o_sorts        LONGTEXT CHARSET utf8mb4 COLLATE utf8mb4_bin DEFAULT '';
  DECLARE v_sorts        JSON DEFAULT NULL;
  DECLARE v_sort         JSON DEFAULT NULL;
  DECLARE v_column       VARCHAR(64) CHARSET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL;
  DECLARE v_cnt          INT DEFAULT 0;

  IF JSON_VALID(i_conditions) THEN

    IF JSON_CONTAINS_PATH(i_conditions,'one',CONCAT('$.',v_sort_column)) THEN
      SET v_sorts = JSON_EXTRACT(i_conditions,CONCAT('$.',v_sort_column));
    ELSEIF JSON_CONTAINS_PATH(i_conditions,'one', CONCAT('$[*].',v_sort_column)) THEN
      SET v_sorts = JSON_EXTRACT(i_conditions,CONCAT('$[*].',v_sort_column));
      IF (JSON_TYPE(v_sorts) = 'ARRAY') THEN
        SET v_sorts = JSON_EXTRACT(JSON_EXTRACT(i_conditions,CONCAT('$[*].',v_sort_column)),'$[0]');
      END IF;
    END IF;

    IF (v_sorts IS NOT NULL) THEN
      IF (JSON_TYPE(v_sorts) = 'STRING') THEN
        IF (i_column_map IS NULL) OR JSON_CONTAINS_PATH(i_column_map,'one',CONCAT('$.',v_sorts)) THEN
          SET o_sorts = JSON_UNQUOTE(v_sorts);
        END IF;
      ELSEIF (JSON_TYPE(v_sorts) = 'OBJECT') THEN
        SET v_column = JSON_UNQUOTE(JSON_EXTRACT(JSON_KEYS(v_sorts),'$[0]'));
        IF (i_column_map IS NULL) OR JSON_CONTAINS_PATH(i_column_map,'one',CONCAT('$.',v_column)) THEN
          SET o_sorts = CONCAT(v_column, ' ', UPPER(JSON_UNQUOTE(JSON_EXTRACT(v_sorts, CONCAT('$.',v_column)))));
        END IF;
      ELSEIF (JSON_TYPE(v_sorts) = 'ARRAY') THEN
        SET v_cnt = 0;
        WHILE v_cnt < JSON_LENGTH(v_sorts) DO
          SET v_sort = JSON_EXTRACT(v_sorts, CONCAT('$[',v_cnt,']'));
          IF (JSON_TYPE(v_sort) = 'STRING') THEN
            IF (i_column_map IS NULL) OR JSON_CONTAINS_PATH(i_column_map,'one',CONCAT('$.',v_sort)) THEN
              IF (LENGTH(o_sorts) > 0) THEN
                SET o_sorts = CONCAT(o_sorts, ', ');
              END IF;
              SET o_sorts = CONCAT(o_sorts, JSON_UNQUOTE(v_sort));
            END IF;
          ELSEIF (JSON_TYPE(v_sort) = 'OBJECT') THEN
            SET v_column = JSON_UNQUOTE(JSON_EXTRACT(JSON_KEYS(v_sort),'$[0]'));
            IF (i_column_map IS NULL) OR JSON_CONTAINS_PATH(i_column_map,'one',CONCAT('$.',v_column)) THEN
              IF (LENGTH(o_sorts) > 0) THEN
                SET o_sorts = CONCAT(o_sorts, ', ');
              END IF;
              SET o_sorts = CONCAT(o_sorts, v_column, ' ', UPPER(JSON_UNQUOTE(JSON_EXTRACT(v_sort, CONCAT('$.',v_column)))));
            END IF;
          END IF;
          SET v_cnt = v_cnt + 1;
        END WHILE;  
      END IF;
    END IF;

  END IF;
  
  RETURN o_sorts;

END$$

DELIMITER ;