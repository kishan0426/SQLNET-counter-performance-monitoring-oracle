SET SERVEROUTPUT ON SIZE UNLIMITED

DECLARE
    l_sent1       NUMBER;
    l_recv1       NUMBER;
    l_round1      NUMBER;

    l_sent2       NUMBER;
    l_recv2       NUMBER;
    l_round2      NUMBER;

    l_start       TIMESTAMP;
    l_end         TIMESTAMP;
    l_seconds     NUMBER;

    l_sent_mb     NUMBER;
    l_recv_mb     NUMBER;
    l_total_mb    NUMBER;

    l_sent_mbps   NUMBER;
    l_recv_mbps   NUMBER;
    l_total_mbps  NUMBER;

    l_gb_hour     NUMBER;
    l_round_sec   NUMBER;

    -- Graph scale
    l_bar_length  NUMBER;

BEGIN

    ------------------------------------------------------------
    -- START COUNTERS
    ------------------------------------------------------------

    SELECT value
    INTO l_sent1
    FROM v$sysstat
    WHERE name = 'bytes sent via SQL*Net to client';

    SELECT value
    INTO l_recv1
    FROM v$sysstat
    WHERE name = 'bytes received via SQL*Net from client';

    SELECT value
    INTO l_round1
    FROM v$sysstat
    WHERE name = 'SQL*Net roundtrips to/from client';


    l_start := SYSTIMESTAMP;


    ------------------------------------------------------------
    -- MEASUREMENT WINDOW
    ------------------------------------------------------------

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('==============================================');
    DBMS_OUTPUT.PUT_LINE(' Oracle SQL*Net Traffic Monitor');
    DBMS_OUTPUT.PUT_LINE(' Measurement period: 60 seconds');
    DBMS_OUTPUT.PUT_LINE('==============================================');
    DBMS_OUTPUT.PUT_LINE('');

    DBMS_OUTPUT.PUT_LINE('Measuring... please wait 60 seconds...');

    DBMS_LOCK.SLEEP(60);


    ------------------------------------------------------------
    -- END COUNTERS
    ------------------------------------------------------------

    SELECT value
    INTO l_sent2
    FROM v$sysstat
    WHERE name = 'bytes sent via SQL*Net to client';

    SELECT value
    INTO l_recv2
    FROM v$sysstat
    WHERE name = 'bytes received via SQL*Net from client';

    SELECT value
    INTO l_round2
    FROM v$sysstat
    WHERE name = 'SQL*Net roundtrips to/from client';


    l_end := SYSTIMESTAMP;


    ------------------------------------------------------------
    -- ACTUAL ELAPSED TIME
    ------------------------------------------------------------

    l_seconds :=
          EXTRACT(DAY    FROM (l_end-l_start)) * 86400
        + EXTRACT(HOUR   FROM (l_end-l_start)) * 3600
        + EXTRACT(MINUTE FROM (l_end-l_start)) * 60
        + EXTRACT(SECOND FROM (l_end-l_start));


    ------------------------------------------------------------
    -- BYTE DELTAS
    ------------------------------------------------------------

    l_sent_mb :=
        (l_sent2 - l_sent1) / 1024 / 1024;

    l_recv_mb :=
        (l_recv2 - l_recv1) / 1024 / 1024;

    l_total_mb :=
        l_sent_mb + l_recv_mb;


    ------------------------------------------------------------
    -- MB / SECOND
    ------------------------------------------------------------

    l_sent_mbps :=
        l_sent_mb / l_seconds;

    l_recv_mbps :=
        l_recv_mb / l_seconds;

    l_total_mbps :=
        l_total_mb / l_seconds;


    ------------------------------------------------------------
    -- CONVERT TO NETWORK Mbps
    --
    -- 1 MB = 8 megabits
    ------------------------------------------------------------

    l_sent_mbps :=
        l_sent_mbps * 8;

    l_recv_mbps :=
        l_recv_mbps * 8;

    l_total_mbps :=
        l_total_mbps * 8;


    ------------------------------------------------------------
    -- GB / HOUR
    ------------------------------------------------------------

    l_gb_hour :=
        (l_total_mb / 1024)
        * (3600 / l_seconds);


    ------------------------------------------------------------
    -- ROUND TRIPS / SECOND
    ------------------------------------------------------------

    l_round_sec :=
        (l_round2 - l_round1) / l_seconds;


    ------------------------------------------------------------
    -- RESULTS
    ------------------------------------------------------------

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('--------------- RESULTS ----------------');
    DBMS_OUTPUT.PUT_LINE('');

    DBMS_OUTPUT.PUT_LINE(
        'Measurement time : ' ||
        ROUND(l_seconds,2) || ' seconds'
    );

    DBMS_OUTPUT.PUT_LINE('');

    DBMS_OUTPUT.PUT_LINE(
        'Sent to client   : ' ||
        ROUND(l_sent_mb,2) || ' MB'
    );

    DBMS_OUTPUT.PUT_LINE(
        'Received client  : ' ||
        ROUND(l_recv_mb,2) || ' MB'
    );

    DBMS_OUTPUT.PUT_LINE(
        'Total traffic    : ' ||
        ROUND(l_total_mb,2) || ' MB'
    );

    DBMS_OUTPUT.PUT_LINE('');

    DBMS_OUTPUT.PUT_LINE(
        'Send rate        : ' ||
        ROUND(l_sent_mbps,2) || ' Mbps'
    );

    DBMS_OUTPUT.PUT_LINE(
        'Receive rate     : ' ||
        ROUND(l_recv_mbps,2) || ' Mbps'
    );

    DBMS_OUTPUT.PUT_LINE(
        'TOTAL RATE       : ' ||
        ROUND(l_total_mbps,2) || ' Mbps'
    );

    DBMS_OUTPUT.PUT_LINE('');

    DBMS_OUTPUT.PUT_LINE(
        'Traffic / hour   : ' ||
        ROUND(l_gb_hour,2) || ' GB/hour'
    );

    DBMS_OUTPUT.PUT_LINE(
        'Round trips/sec  : ' ||
        ROUND(l_round_sec,2)
    );

    DBMS_OUTPUT.PUT_LINE('');


    ------------------------------------------------------------
    -- SIMPLE GRAPH
    ------------------------------------------------------------

    DBMS_OUTPUT.PUT_LINE('--------------- TRAFFIC GRAPH -----------');
    DBMS_OUTPUT.PUT_LINE('');

    DBMS_OUTPUT.PUT_LINE(
        'SEND     ' ||
        RPAD(
            '#',
            LEAST(50, GREATEST(1, ROUND(l_sent_mbps / 10))),
            '#'
        ) ||
        ' ' || ROUND(l_sent_mbps,2) || ' Mbps'
    );

    DBMS_OUTPUT.PUT_LINE(
        'RECEIVE  ' ||
        RPAD(
            '#',
            LEAST(50, GREATEST(1, ROUND(l_recv_mbps / 10))),
            '#'
        ) ||
        ' ' || ROUND(l_recv_mbps,2) || ' Mbps'
    );

    DBMS_OUTPUT.PUT_LINE(
        'TOTAL    ' ||
        RPAD(
            '#',
            LEAST(50, GREATEST(1, ROUND(l_total_mbps / 10))),
            '#'
        ) ||
        ' ' || ROUND(l_total_mbps,2) || ' Mbps'
    );

    DBMS_OUTPUT.PUT_LINE('');

    DBMS_OUTPUT.PUT_LINE(
        'Graph scale: approximately 1 # = 10 Mbps'
    );

    DBMS_OUTPUT.PUT_LINE('');

END;
/
