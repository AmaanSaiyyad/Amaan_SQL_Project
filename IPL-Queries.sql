/* =========================================================================== 
======================  OBJECTIVE QUESTIONS  =================================
=========================================================================== */


USE ipl;


# Question 1.- Different dtypes of columns in table “ball_by_ball” (using information schema)

select data_type, COLUMN_NAME from information_schema.columns
where table_name = 'Ball_by_Ball' and table_schema = 'ipl';



# Question 2.- What is the total number of runs scored in 1st season by RCB (bonus: also include the extra runs using the extra runs table)

SELECT 
    t.Team_Name,
    SUM(b.Runs_Scored + COALESCE(er.Extra_Runs, 0)) AS Total_Runs
FROM Ball_by_Ball b
JOIN Matches m 
    ON m.Match_Id = b.Match_Id
JOIN Team t 
    ON t.Team_Id = b.Team_Batting
LEFT JOIN Extra_Runs er 
    ON er.Match_Id = b.Match_Id
   AND er.Over_Id = b.Over_Id
   AND er.Ball_Id = b.Ball_Id
   AND er.Innings_No = b.Innings_No
WHERE t.Team_Name = 'Royal Challengers Bangalore'
  AND m.Season_Id = (
        SELECT MIN(Season_Id) FROM Matches
  )
GROUP BY t.Team_Name;



# Question 3.- How many players were more than the age of 25 during season 2014?

SELECT 
    COUNT(DISTINCT p.Player_Id) AS Players_Above_25
FROM Player p
JOIN Player_Match pm 
    ON pm.Player_Id = p.Player_Id
JOIN Matches m 
    ON m.Match_Id = pm.Match_Id
JOIN Season s 
    ON s.Season_Id = m.Season_Id
WHERE s.Season_Year = 2014
  AND TIMESTAMPDIFF(YEAR, p.DOB, '2014-01-01') > 25;
  
  
  
# Question 4.-How many matches did RCB win in 2013? 

SELECT 
    COUNT(*) AS Matches_Won_By_RCB
FROM Matches m
JOIN Season s 
    ON s.Season_Id = m.Season_Id
WHERE s.Season_Year = 2013
  AND m.Match_Winner = (
        SELECT Team_Id 
        FROM Team 
        WHERE Team_Name = 'Royal Challengers Bangalore'
  );




# Question 5.- List the top 10 players according to their strike rate in the last 4 seasons

WITH last_4_seasons AS (
    SELECT Season_Id
    FROM Season
    ORDER BY Season_Year DESC
    LIMIT 4
),
player_stats AS (
    SELECT 
        b.Striker AS Player_Id,
        SUM(b.Runs_Scored) AS Total_Runs,
        COUNT(*) AS Balls_Faced
    FROM Ball_by_Ball b
    JOIN Matches m 
        ON m.Match_Id = b.Match_Id
    WHERE m.Season_Id IN (SELECT Season_Id FROM last_4_seasons)
    GROUP BY b.Striker
)
SELECT 
    p.Player_Name,
    ROUND((ps.Total_Runs / ps.Balls_Faced) * 100, 2) AS Strike_Rate
FROM player_stats ps
JOIN Player p 
    ON p.Player_Id = ps.Player_Id
WHERE ps.Balls_Faced > 0
ORDER BY Strike_Rate DESC
LIMIT 10;




# Question 6.-What are the average runs scored by each batsman considering all the seasons?

SELECT 
    p.Player_Name,
    ROUND(SUM(b.Runs_Scored) / COUNT(DISTINCT pm.Match_Id), 2) AS Average_Runs
FROM Player p
JOIN Ball_by_Ball b
    ON b.Striker = p.Player_Id
JOIN Player_Match pm
    ON pm.Player_Id = p.Player_Id
   AND pm.Match_Id = b.Match_Id
GROUP BY p.Player_Id, p.Player_Name
HAVING COUNT(DISTINCT pm.Match_Id) > 0
ORDER BY Average_Runs DESC ;




# Question 7.- What are the average wickets taken by each bowler considering all the seasons?

SELECT 
    p.Player_Name,
    ROUND(COUNT(w.Player_Out) / COUNT(DISTINCT pm.Match_Id), 2) AS Average_Wickets
FROM Player p
JOIN Wicket_Taken w
    ON w.Player_Out IS NOT NULL
JOIN Ball_by_Ball b
    ON b.Match_Id = w.Match_Id
   AND b.Over_Id = w.Over_Id
   AND b.Ball_Id = w.Ball_Id
   AND b.Innings_No = w.Innings_No
   AND b.Bowler = p.Player_Id
JOIN Player_Match pm
    ON pm.Player_Id = p.Player_Id
   AND pm.Match_Id = b.Match_Id
GROUP BY p.Player_Id, p.Player_Name
HAVING COUNT(DISTINCT pm.Match_Id) > 0
ORDER BY Average_Wickets DESC;




# Question 8.- List all the players who have average runs scored greater than the overall average and who have taken wickets greater than the overall average

WITH batting AS (
    SELECT
        Striker AS Player_Id,
        ROUND(
            SUM(Runs_Scored) * 1.0 /
            COUNT(DISTINCT CONCAT(Match_Id, '-', Innings_No)), 2
        ) AS Avg_Runs
    FROM Ball_by_Ball
    GROUP BY Striker
),
bowling AS (
    SELECT
        b.Bowler AS Player_Id,
        COUNT(w.Player_Out) AS Total_Wickets
    FROM Ball_by_Ball b
    JOIN Wicket_Taken w
        ON b.Match_Id = w.Match_Id
       AND b.Over_Id = w.Over_Id
       AND b.Ball_Id = w.Ball_Id
       AND b.Innings_No = w.Innings_No
    GROUP BY b.Bowler
)
SELECT
    p.Player_Name,
    bat.Avg_Runs,
    bowl.Total_Wickets
FROM batting bat
JOIN bowling bowl
    ON bat.Player_Id = bowl.Player_Id
JOIN Player p
    ON p.Player_Id = bat.Player_Id
WHERE
    bat.Avg_Runs >
        (SELECT AVG(Avg_Runs) FROM batting)
AND
    bowl.Total_Wickets >
        (SELECT AVG(Total_Wickets) FROM bowling) ORDER BY Avg_Runs DESC ;




# Question 9.- Create a table rcb_record table that shows the wins and losses of RCB in an individual venue.

CREATE TABLE rcb_record AS
SELECT
    v.Venue_Name,
    SUM(
        CASE 
            WHEN m.Match_Winner = rcb.Team_Id THEN 1 
            ELSE 0 
        END
    ) AS Wins,
    SUM(
        CASE 
            WHEN m.Match_Winner <> rcb.Team_Id THEN 1 
            ELSE 0 
        END
    ) AS Losses
FROM Matches m
JOIN Venue v 
    ON v.Venue_Id = m.Venue_Id
JOIN (
    SELECT Team_Id 
    FROM Team 
    WHERE Team_Name = 'Royal Challengers Bangalore'
) rcb
WHERE m.Team_1 = rcb.Team_Id
   OR m.Team_2 = rcb.Team_Id
GROUP BY v.Venue_Name ORDER BY Wins DESC;

SELECT * FROM rcb_record;




# Question 10.- What is the impact of bowling style on wickets taken?

SELECT
    bs.Bowling_skill AS Bowling_Style_Name,
    COUNT(w.Player_Out) AS Total_Wickets
FROM Player p
JOIN bowling_style bs
    ON bs.Bowling_Id = p.Bowling_Skill
JOIN Ball_by_Ball b
    ON b.Bowler = p.Player_Id
JOIN Wicket_Taken w
    ON w.Match_Id = b.Match_Id
   AND w.Over_Id = b.Over_Id
   AND w.Ball_Id = b.Ball_Id
   AND w.Innings_No = b.Innings_No
GROUP BY bs.Bowling_skill
ORDER BY Total_Wickets DESC;




# Question 11. Write the SQL query to provide a status of whether the performance of the team is better than the previous year's performance 
# on the basis of the number of runs scored by the team in the season and the number of wickets taken 

WITH team_stats AS (
    SELECT
        m.Season_Id,
        b.Team_Batting AS Team_Id,
        SUM(b.Runs_Scored) AS Total_Runs
    FROM Ball_by_Ball b
    JOIN Matches m
        ON b.Match_Id = m.Match_Id
    GROUP BY m.Season_Id, b.Team_Batting
),
team_wickets AS (
    SELECT
        m.Season_Id,
        b.Team_Bowling AS Team_Id,
        COUNT(w.Player_Out) AS Total_Wickets
    FROM Ball_by_Ball b
    JOIN Matches m
        ON b.Match_Id = m.Match_Id
    JOIN Wicket_Taken w
        ON b.Match_Id = w.Match_Id
       AND b.Over_Id = w.Over_Id
       AND b.Ball_Id = w.Ball_Id
       AND b.Innings_No = w.Innings_No
    GROUP BY m.Season_Id, b.Team_Bowling
),
season_stats AS (
    SELECT
        s.Season_Year,
        t.Team_Name,
        r.Team_Id,
        r.Total_Runs,
        w.Total_Wickets,
        LAG(r.Total_Runs) OVER (PARTITION BY r.Team_Id ORDER BY s.Season_Year) AS Prev_Total_Runs,
        LAG(w.Total_Wickets) OVER (PARTITION BY r.Team_Id ORDER BY s.Season_Year) AS Prev_Total_Wickets
    FROM team_stats r
    JOIN team_wickets w
        ON r.Season_Id = w.Season_Id
       AND r.Team_Id = w.Team_Id
    JOIN Season s
        ON s.Season_Id = r.Season_Id
    JOIN Team t
        ON t.Team_Id = r.Team_Id
)
SELECT
    Team_Name,
    Season_Year,
    Total_Runs,
    Total_Wickets,
    Prev_Total_Runs,
    Prev_Total_Wickets,
    CASE
        WHEN Total_Runs > Prev_Total_Runs
         AND Total_Wickets > Prev_Total_Wickets
        THEN 'Improved'
        WHEN Total_Runs < Prev_Total_Runs
         AND Total_Wickets < Prev_Total_Wickets
        THEN 'Declined'
        ELSE 'Same'
    END AS Performance_Status
FROM season_stats
WHERE Prev_Total_Runs IS NOT NULL
ORDER BY Team_Name, Season_Year;




# Question 12.- Can you derive more KPIs for the team strategy?


# KPI 1: Win Percentage

SELECT
    t.Team_Name,
    COUNT(m.Match_Id) AS Matches_Played,
    SUM(CASE WHEN m.Match_Winner = t.Team_Id THEN 1 ELSE 0 END) AS Matches_Won,
    ROUND(
        (SUM(CASE WHEN m.Match_Winner = t.Team_Id THEN 1 ELSE 0 END) * 100.0) 
        / COUNT(m.Match_Id), 2
    ) AS Win_Percentage
FROM Matches m
JOIN Team t
    ON t.Team_Id = m.Team_1 OR t.Team_Id = m.Team_2
GROUP BY t.Team_Name
ORDER BY Win_Percentage DESC;


# KPI 2: Average Runs per Match (Batting Strength)

SELECT
    t.Team_Name,
    ROUND(
        SUM(b.Runs_Scored) / COUNT(DISTINCT b.Match_Id), 2
    ) AS Avg_Runs_Per_Match
FROM Ball_by_Ball b
JOIN Team t
    ON t.Team_Id = b.Team_Batting
GROUP BY t.Team_Name
ORDER BY Avg_Runs_Per_Match DESC;


# KPI 3: Average Wickets per Match (Bowling Strength)

SELECT
    t.Team_Name,
    ROUND(
        COUNT(w.Player_Out) / COUNT(DISTINCT b.Match_Id), 2
    ) AS Avg_Wickets_Per_Match
FROM Ball_by_Ball b
JOIN Team t
    ON t.Team_Id = b.Team_Bowling
JOIN Wicket_Taken w
    ON w.Match_Id = b.Match_Id
   AND w.Over_Id = b.Over_Id
   AND w.Ball_Id = b.Ball_Id
   AND w.Innings_No = b.Innings_No
GROUP BY t.Team_Name
ORDER BY Avg_Wickets_Per_Match DESC;


# KPI 4: Run Rate (Scoring Speed)

SELECT
    t.Team_Name,
    ROUND(
        SUM(b.Runs_Scored) / COUNT(*), 2
    ) AS Run_Rate
FROM Ball_by_Ball b
JOIN Team t
    ON t.Team_Id = b.Team_Batting
GROUP BY t.Team_Name
ORDER BY Run_Rate DESC;


# KPI 5: Toss Impact KPI (Strategic Advantage)

SELECT
    t.Team_Name,
    COUNT(m.Match_Id) AS Toss_Wins,
    SUM(CASE WHEN m.Match_Winner = m.Toss_Winner THEN 1 ELSE 0 END) AS Wins_After_Toss,
    ROUND(
        (SUM(CASE WHEN m.Match_Winner = m.Toss_Winner THEN 1 ELSE 0 END) * 100.0) 
        / COUNT(m.Match_Id), 2
    ) AS Win_Percentage_After_Toss
FROM Matches m
JOIN Team t
    ON t.Team_Id = m.Toss_Winner
GROUP BY t.Team_Name
ORDER BY Win_Percentage_After_Toss DESC;




# Question 13.- Using SQL, write a query to find out the average wickets taken by each bowler in each venue. Also, rank the gender according to the average value.

WITH bowler_venue_stats AS (
    SELECT
        v.Venue_Name,
        p.Player_Name,
        COUNT(w.Player_Out) AS Total_Wickets,
        COUNT(DISTINCT b.Match_Id) AS Matches_Played
    FROM Ball_by_Ball b
    JOIN Wicket_Taken w
        ON b.Match_Id = w.Match_Id
       AND b.Over_Id = w.Over_Id
       AND b.Ball_Id = w.Ball_Id
       AND b.Innings_No = w.Innings_No
    JOIN Matches m
        ON b.Match_Id = m.Match_Id
    JOIN Venue v
        ON m.Venue_Id = v.Venue_Id
    JOIN Player p
        ON b.Bowler = p.Player_Id
    GROUP BY
        v.Venue_Name,
        p.Player_Name
)
SELECT
    Venue_Name,
    Player_Name,
    Total_Wickets,
    Matches_Played,
    ROUND(Total_Wickets * 1.0 / Matches_Played, 2) AS Average_Wickets,
    RANK() OVER (
        ORDER BY (Total_Wickets * 1.0 / Matches_Played) DESC
    ) AS Overall_Rank
FROM bowler_venue_stats
ORDER BY Overall_Rank;




# Question 14.- Which of the given players have consistently performed well in past seasons? (will you use any visualization to solve the problem)

# For Batting Player

SELECT
    p.Player_Name,
    s.Season_Year,
    SUM(b.Runs_Scored) AS Total_Runs
FROM Ball_by_Ball b
JOIN Matches m 
    ON b.Match_Id = m.Match_Id
JOIN Season s 
    ON m.Season_Id = s.Season_Id
JOIN Player p 
    ON b.Striker = p.Player_Id
GROUP BY
    p.Player_Name, s.Season_Year
ORDER BY
    p.Player_Name, s.Season_Year;


# For Bowling Player

SELECT
    p.Player_Name,
    s.Season_Year,
    COUNT(w.Player_Out) AS Total_Wickets
FROM Ball_by_Ball b
JOIN Wicket_Taken w
    ON b.Match_Id = w.Match_Id
   AND b.Over_Id = w.Over_Id
   AND b.Ball_Id = w.Ball_Id
   AND b.Innings_No = w.Innings_No
JOIN Matches m 
    ON b.Match_Id = m.Match_Id
JOIN Season s 
    ON m.Season_Id = s.Season_Id
JOIN Player p 
    ON b.Bowler = p.Player_Id
GROUP BY
    p.Player_Name, s.Season_Year
ORDER BY
    p.Player_Name, s.Season_Year;




# Question 15.- Are there players whose performance is more suited to specific venues or conditions? (how would you present this using charts?)


# For Batting Player

WITH venue_runs AS (
    SELECT
        v.Venue_Name,
        p.Player_Name,
        SUM(b.Runs_Scored) AS Total_Runs
    FROM Ball_by_Ball b
    JOIN Matches m
        ON b.Match_Id = m.Match_Id
    JOIN Venue v
        ON m.Venue_Id = v.Venue_Id
    JOIN Player p
        ON b.Striker = p.Player_Id
    GROUP BY
        v.Venue_Name,
        p.Player_Name
),
ranked_runs AS (
    SELECT
        Venue_Name,
        Player_Name,
        Total_Runs,
        RANK() OVER (
            PARTITION BY Venue_Name
            ORDER BY Total_Runs DESC
        ) AS Rank_in_Stadium
    FROM venue_runs
)
SELECT
    Venue_Name,
    Player_Name,
    Total_Runs
FROM ranked_runs
WHERE Rank_in_Stadium = 1
ORDER BY Total_runs DESC;



# For Bowling Player

WITH venue_wickets AS (
    SELECT
        v.Venue_Name,
        p.Player_Name,
        COUNT(w.Player_Out) AS Total_Wickets
    FROM Ball_by_Ball b
    JOIN Wicket_Taken w
        ON b.Match_Id = w.Match_Id
       AND b.Over_Id = w.Over_Id
       AND b.Ball_Id = w.Ball_Id
       AND b.Innings_No = w.Innings_No
    JOIN Matches m
        ON b.Match_Id = m.Match_Id
    JOIN Venue v
        ON m.Venue_Id = v.Venue_Id
    JOIN Player p
        ON b.Bowler = p.Player_Id
    GROUP BY
        v.Venue_Name,
        p.Player_Name
),
ranked_wickets AS (
    SELECT
        Venue_Name,
        Player_Name,
        Total_Wickets,
        RANK() OVER (
            PARTITION BY Venue_Name
            ORDER BY Total_Wickets DESC
        ) AS Rank_in_Stadium
    FROM venue_wickets
)
SELECT
    Venue_Name,
    Player_Name,
    Total_Wickets
FROM ranked_wickets
WHERE Rank_in_Stadium = 1
ORDER BY Total_Wickets DESC; 








/*=============================================================================
======================  SUBJECTIVE QUESTIONS  =================================
============================================================================ */



# Question 1.-How does the toss decision affect the result of the match? (which visualizations could be used to present your answer better) And is the impact limited to only specific venues?


SELECT 
    v.Venue_Name,
    td.Toss_Name AS Toss_Decision,
    COUNT(m.Match_Id) AS Total_Matches,
    SUM(CASE 
            WHEN m.Toss_Winner = m.Match_Winner THEN 1 
            ELSE 0 
        END) AS Toss_Win_And_Match_Win,
    ROUND(
        (SUM(CASE 
                WHEN m.Toss_Winner = m.Match_Winner THEN 1 
                ELSE 0 
             END) * 100.0) / COUNT(m.Match_Id), 
        2
    ) AS Win_Percentage
FROM Matches m
JOIN Toss_Decision td 
    ON m.Toss_Decide = td.Toss_Id
JOIN Venue v 
    ON m.Venue_Id = v.Venue_Id
GROUP BY 
    v.Venue_Name,
    td.Toss_Name
ORDER BY 
    Win_Percentage DESC;




# Question 2.-	Suggest some of the players who would be best fit for the team.

SELECT 
    p.Player_Name,

    /* Consistency */
    COUNT(DISTINCT b.Match_Id) AS Matches_Played,

    /* Batting metrics */
    SUM(CASE 
            WHEN b.Striker = p.Player_Id THEN IFNULL(b.Runs_Scored,0)
            ELSE 0
        END) AS Total_Runs,

    COUNT(CASE 
            WHEN b.Striker = p.Player_Id THEN 1
        END) AS Balls_Faced,

    /* Bowling involvement */
    COUNT(CASE 
            WHEN b.Bowler = p.Player_Id THEN 1
        END) AS Balls_Bowled

FROM Player p
JOIN Ball_by_Ball b
    ON p.Player_Id IN (b.Striker, b.Non_Striker, b.Bowler)

GROUP BY 
    p.Player_Id, p.Player_Name

HAVING 
    Total_Runs > 0
    AND Balls_Bowled > 0

ORDER BY 
    Matches_Played DESC,
    Total_Runs DESC,
    Balls_Bowled DESC

LIMIT 10;


# Question 3 - Solution for this question is in documnts file


# Question 4.- Which players offer versatility in their skills and can contribute effectively with both bat and ball? (can you visualize the data for the same)

SELECT 
    p.Player_Name,
    SUM(CASE 
            WHEN b.Striker = p.Player_Id THEN b.Runs_Scored 
            ELSE 0 
        END) AS Total_Runs,
    COUNT(CASE 
            WHEN b.Bowler = p.Player_Id THEN 1 
        END) AS Balls_Bowled
FROM Player p
JOIN Ball_by_Ball b
    ON p.Player_Id IN (b.Striker, b.Bowler)
GROUP BY p.Player_Id, p.Player_Name
HAVING 
    Total_Runs >= 500   
    AND Balls_Bowled >= 150 
ORDER BY 
    Total_Runs DESC,
    Balls_Bowled DESC;




# Question 5.- Are there players whose presence positively influences the morale and performance of the team? (justify your answer using visualization)

SELECT 
    p.Player_Name,

    /* Leadership & presence */
    COUNT(DISTINCT m.Match_Id) AS Matches_Played,

    /* Pressure exposure */
    COUNT(DISTINCT CASE 
        WHEN m.Match_Winner IS NOT NULL THEN m.Match_Id
    END) AS Matches_With_Result,

    /* Performance consistency */
    ROUND(
        SUM(b.Runs_Scored) / COUNT(DISTINCT m.Match_Id),
        2
    ) AS Avg_Runs_Per_Match

FROM Player p
JOIN Ball_by_Ball b
    ON p.Player_Id = b.Striker
JOIN Matches m
    ON b.Match_Id = m.Match_Id

GROUP BY 
    p.Player_Id, p.Player_Name

HAVING 
    COUNT(DISTINCT m.Match_Id) >= 30

ORDER BY 
    Matches_Played DESC,
    Avg_Runs_Per_Match DESC

LIMIT 10;




# Question 6.- What would you suggest to RCB before going to the mega auction? 


# Ouery 1: Retain / Target Consistent Batters (Stability First)

SELECT 
    p.Player_Name,
    COUNT(DISTINCT m.Match_Id) AS Matches_Played,
    ROUND(SUM(b.Runs_Scored) / COUNT(DISTINCT m.Match_Id), 2) AS Avg_Runs_Per_Match
FROM Player p
JOIN Ball_by_Ball b
    ON p.Player_Id = b.Striker
JOIN Matches m
    ON b.Match_Id = m.Match_Id
GROUP BY p.Player_Id, p.Player_Name
HAVING COUNT(DISTINCT m.Match_Id) >= 30
ORDER BY Avg_Runs_Per_Match DESC;


# Query 2: Invest in Genuine All-Rounders

SELECT 
    p.Player_Name,
    SUM(CASE 
            WHEN b.Striker = p.Player_Id THEN b.Runs_Scored 
            ELSE 0 
        END) AS Total_Runs,
    COUNT(CASE 
            WHEN b.Bowler = p.Player_Id THEN 1 
        END) AS Balls_Bowled
FROM Player p
JOIN Ball_by_Ball b
    ON p.Player_Id IN (b.Striker, b.Bowler)
GROUP BY p.Player_Id, p.Player_Name
HAVING Total_Runs >= 500 AND Balls_Bowled >= 150
ORDER BY Total_Runs DESC, Balls_Bowled DESC;


# Query 3: Strengthen Bowling with High-Involvement Bowlers

SELECT 
    p.Player_Name,
    COUNT(*) AS Balls_Bowled
FROM Player p
JOIN Ball_by_Ball b
    ON p.Player_Id = b.Bowler
GROUP BY p.Player_Id, p.Player_Name
ORDER BY Balls_Bowled DESC;




# Question 7.-	What do you think could be the factors contributing to the high-scoring matches and the impact on viewership and team strategies Venue Affect


# Query 1 Average runs scored per match (season-wise)

SELECT 
    s.Season_Year,
    ROUND(SUM(b.Runs_Scored) / COUNT(DISTINCT b.Match_Id), 2) AS Avg_Runs_Per_Match
FROM Ball_by_Ball b
JOIN Matches m ON b.Match_Id = m.Match_Id
JOIN Season s ON m.Season_Id = s.Season_Id
GROUP BY s.Season_Year
ORDER BY s.Season_Year;


# Query 2 Count of fours and sixes per season

SELECT 
    s.Season_Year,
    SUM(CASE WHEN b.Runs_Scored = 4 THEN 1 ELSE 0 END) AS Total_Fours,
    SUM(CASE WHEN b.Runs_Scored = 6 THEN 1 ELSE 0 END) AS Total_Sixes
FROM Ball_by_Ball b
JOIN Matches m ON b.Match_Id = m.Match_Id
JOIN Season s ON m.Season_Id = s.Season_Id
GROUP BY s.Season_Year
ORDER BY s.Season_Year;


# Query 3 Matches won while chasing

SELECT 
    COUNT(*) AS Matches_Won_While_Chasing
FROM Matches
WHERE Toss_Decide = 2
  AND Match_Winner = Toss_Winner;


# Query 4 Average runs per venue

SELECT 
    v.Venue_Name,
    ROUND(AVG(b.Runs_Scored), 2) AS Avg_Runs_Per_Ball
FROM Ball_by_Ball b
JOIN Matches m ON b.Match_Id = m.Match_Id
JOIN Venue v ON m.Venue_Id = v.Venue_Id
GROUP BY v.Venue_Name
ORDER BY Avg_Runs_Per_Ball DESC;




# Question 8.- Analyze the impact of home-ground advantage on team performance and identify strategies to maximize this advantage for RCB.

SELECT 
    CASE 
        WHEN c.City_Name = 'Bangalore' THEN 'Home'
        ELSE 'Away'
    END AS match_location,
    COUNT(*) AS matches_played,
    SUM(CASE WHEN m.Match_Winner = t.Team_Id THEN 1 ELSE 0 END) AS matches_won,
    ROUND(
        (SUM(CASE WHEN m.Match_Winner = t.Team_Id THEN 1 ELSE 0 END) * 100.0) 
        / COUNT(*), 2
    ) AS win_percentage
FROM Matches m
JOIN Team t 
    ON t.Team_Name = 'Royal Challengers Bangalore'
JOIN Venue v 
    ON m.Venue_Id = v.Venue_Id
JOIN City c 
    ON v.City_Id = c.City_Id
WHERE m.Team_1 = t.Team_Id 
   OR m.Team_2 = t.Team_Id
GROUP BY match_location;




# Question 9.- Come up with a visual and analytical analysis of the RCB's past season's performance and potential reasons for them not winning a trophy. Past years performance by RCB


# Query 1 : Season-wise performance of RCB

SELECT
    s.Season_Year,
    COUNT(*) AS matches_played,
    SUM(CASE WHEN m.Match_Winner = rcb.Team_Id THEN 1 ELSE 0 END) AS wins,
    ROUND(
        100.0 * SUM(CASE WHEN m.Match_Winner = rcb.Team_Id THEN 1 ELSE 0 END) / COUNT(*),
        2
    ) AS win_percentage
FROM Matches m
JOIN Season s ON s.Season_Id = m.Season_Id
JOIN (SELECT Team_Id FROM Team WHERE Team_Name LIKE '%Royal Challengers%') rcb
  ON m.Team_1 = rcb.Team_Id OR m.Team_2 = rcb.Team_Id
GROUP BY s.Season_Year
ORDER BY s.Season_Year;


# Query 2 : Close matches lost by RCB

SELECT
    s.Season_Year,
    COUNT(*) AS close_losses
FROM Matches m
JOIN Season s ON s.Season_Id = m.Season_Id
JOIN (SELECT Team_Id FROM Team WHERE Team_Name LIKE '%Royal Challengers%') rcb
  ON m.Team_1 = rcb.Team_Id OR m.Team_2 = rcb.Team_Id
WHERE m.Match_Winner IS NOT NULL
  AND m.Match_Winner <> rcb.Team_Id
  AND (
        (m.Win_Type = 1 AND m.Win_Margin <= 10)
     OR (m.Win_Type = 2 AND m.Win_Margin <= 2)
  )
GROUP BY s.Season_Year
ORDER BY s.Season_Year;


# Query 3 : Wins while batting first vs chasing

SELECT
    s.Season_Year,
    SUM(
      CASE
        WHEN (
          (m.Toss_Winner = rcb.Team_Id AND m.Toss_Decide = 1)
          OR (m.Toss_Winner <> rcb.Team_Id AND m.Toss_Decide = 2)
        ) AND m.Match_Winner = rcb.Team_Id
        THEN 1 ELSE 0
      END
    ) AS wins_batting_first,
    SUM(
      CASE
        WHEN (
          (m.Toss_Winner = rcb.Team_Id AND m.Toss_Decide = 2)
          OR (m.Toss_Winner <> rcb.Team_Id AND m.Toss_Decide = 1)
        ) AND m.Match_Winner = rcb.Team_Id
        THEN 1 ELSE 0
      END
    ) AS wins_chasing
FROM Matches m
JOIN Season s ON s.Season_Id = m.Season_Id
JOIN (SELECT Team_Id FROM Team WHERE Team_Name LIKE '%Royal Challengers%') rcb
  ON m.Team_1 = rcb.Team_Id OR m.Team_2 = rcb.Team_Id
GROUP BY s.Season_Year
ORDER BY s.Season_Year;



# Query 4 : Runs scored by RCB vs runs allowed to opponents

SELECT
    s.Season_Year,
    SUM(
      CASE WHEN b.Team_Batting = rcb.Team_Id
      THEN IFNULL(b.Runs_Scored,0) + IFNULL(er.Extra_Runs,0)
      ELSE 0 END
    ) AS runs_scored,
    SUM(
      CASE WHEN b.Team_Bowling = rcb.Team_Id
      THEN IFNULL(b.Runs_Scored,0) + IFNULL(er.Extra_Runs,0)
      ELSE 0 END
    ) AS runs_allowed
FROM Ball_by_Ball b
JOIN Matches m ON m.Match_Id = b.Match_Id
JOIN Season s ON s.Season_Id = m.Season_Id
LEFT JOIN Extra_Runs er
  ON er.Match_Id = b.Match_Id
 AND er.Over_Id = b.Over_Id
 AND er.Ball_Id = b.Ball_Id
 AND er.Innings_No = b.Innings_No
JOIN (SELECT Team_Id FROM Team WHERE Team_Name LIKE '%Royal Challengers%') rcb
  ON m.Team_1 = rcb.Team_Id OR m.Team_2 = rcb.Team_Id
GROUP BY s.Season_Year
ORDER BY s.Season_Year;




# Question 10.- Solution for this question is in documnts file, because it's a theory question



# Question 11.- In the "Match" table, some entries in the "Opponent_Team" column are incorrectly spelled as "Delhi_Capitals" instead of "Delhi_Daredevils". Write an SQL query to replace all occurrences of "Delhi_Capitals" with "Delhi_Daredevils".

UPDATE Matches
SET Opponent_Team = 'Delhi_Daredevils'
WHERE Opponent_Team = 'Delhi_Capitals';





