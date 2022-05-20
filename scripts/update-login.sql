UPDATE `login`
SET 
     userid = 'serverconn'
    ,user_pass = 'password'
    ,email = ''
WHERE account_id = 1;

INSERT INTO `login` (`account_id`, `userid`, `user_pass`, `sex`, `group_id`) 
VALUES (2000000, 'adminacc', 'password', 'M', 99);