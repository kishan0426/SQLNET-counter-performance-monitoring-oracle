SET SERVEROUTPUT ON

DECLARE
    l_sent1     NUMBER;
    l_recv1     NUMBER;
    l_round1    NUMBER;

    l_sent2     NUMBER;
    l_recv2     NUMBER;
    l_round2    NUMBER;

    l_start     TIMESTAMP;
    l_end       TIMESTAMP;
    l_seconds   NUMBER;
BEGIN
    SELECT value INTO l_sent1
    FROM v$sysstat
    WHERE name = 'bytes sent via SQL*Net to client';

    SELECT value INTO l_recv1
    FROM v$sysstat
    WHERE name = 'bytes received via SQL*Net from client';

    SELECT value INTO l_round1
    FROM v$sysstat
    WHERE name = 'SQL*Net roundtrips to/from client';

    l_start := SYSTIMESTAMP;

    DBMS_LOCK.SLEEP(60);

    SELECT value INTO l_sent2
    FROM v$sysstat
    WHERE name = 'bytes sent via SQL*Net to client';

    SELECT value INTO l_recv2
    FROM v$sysstat
    WHERE name = 'bytes received via SQL*Net from client';

    SELECT value INTO l_round2
    FROM v$sysstat
    WHERE name = 'SQL*Net roundtrips to/from client';

    l_end := SYSTIMESTAMP;

    l_seconds :=
        EXTRACT(DAY    FROM (l_end-l_start)) * 86400 +
        EXTRACT(HOUR   FROM (l_end-l_start)) * 3600 +
        EXTRACT(MINUTE FROM (l_end-l_start)) * 60 +
        EXTRACT(SECOND FROM (l_end-l_start));

    DBMS_OUTPUT.PUT_LINE(
        'Sent MB/sec     : ' ||
        ROUND((l_sent2-l_sent1)/1024/1024/l_seconds,2)
    );

    DBMS_OUTPUT.PUT_LINE(
        'Received MB/sec : ' ||
        ROUND((l_recv2-l_recv1)/1024/1024/l_seconds,2)
    );

    DBMS_OUTPUT.PUT_LINE(
        'Total MB/sec    : ' ||
        ROUND(
          ((l_sent2-l_sent1)+(l_recv2-l_recv1))
          /1024/1024/l_seconds,
          2
        )
    );

    DBMS_OUTPUT.PUT_LINE(
        'Roundtrips/sec  : ' ||
        ROUND((l_round2-l_round1)/l_seconds,2)
    );
END;
/
