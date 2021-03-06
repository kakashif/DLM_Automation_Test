USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetPollsSurvey_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SMG_GetPollsSurvey_XML]
	@maxPolls INT,
    @leagueName VARCHAR(100),
	@seasonKey INT,
	@week INT,
    @xmlData XML
AS
-- =============================================
-- Author:		ikenticus
-- Create date: 05/23/2014
-- Description:	Generate Polls Survey (currently for GISS)
-- Update:		06/19/2014 - ikenticus: preparing @answers for piped answerValue
--				06/24/2014 - ikenticus: adding team_abbr to answerValue
--				06/26/2014 - ikenticus: adding calculateSummaryEveryN as 60 minutes
--				07/09/2014 - ikenticus: setting end date at 11:00, 3 days after start date
--				07/09/2014 - pkamat: setting end date at 12:00 am, 3 days after start date
--				09/08/2014 - pkamat: changing sitecode to USAT for GISS validation
--				07/01/2015 - ikenticus - adjusting to STATS migration and SMG_Polls* conversion
--				07/29/2015 - pkamat - change subsection to football
--				07/30/2015 - ikenticus - replacing team_key with team_abbreviation
--				07/30/2015 - pkamat - reverting subsection to ncaaf, making surveyQuestionGroups as an array
-- =============================================
BEGIN
	SET NOCOUNT ON
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	IF (@maxPolls <= 0)
	BEGIN
		SET @maxPolls = 4	-- default number of polls
	END

    -- Unsupported league     
    IF (@leagueName NOT IN (
		SELECT league_key
		  FROM SportsEditDB.dbo.SMG_Polls
		 GROUP BY league_key
	))
    BEGIN
        RETURN
    END

	-- Determine league_key from leagueName
	DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
	DECLARE @fixture_key VARCHAR(100) = 'smg-usat'

	IF (@seasonKey = 0)
	BEGIN
		SELECT @seasonKey = MAX(season_key)
		  FROM SportsEditDB.dbo.SMG_Polls
		 WHERE league_key = @leagueName AND fixture_key = @fixture_key
		   AND (publish_date_time IS NULL OR publish_date_time < GETDATE())
	END

	IF (@week = 0)
	BEGIN
		SELECT @week = MAX([week])
		  FROM SportsEditDB.dbo.SMG_Polls
		 WHERE league_key = @leagueName AND season_key = @seasonKey AND fixture_key = @fixture_key
		   AND (publish_date_time IS NULL OR publish_date_time < GETDATE())
	END

	-- Create the answers table from specified Top25 poll
	DECLARE @answers TABLE (
		poll_date	DATETIME,
	    answerCopy	VARCHAR(100),
	    answerValue	VARCHAR(100),
	    answerRank	INT IDENTITY,
		answerId	INT
	)
	INSERT INTO @answers (poll_date, answerCopy, answerValue)
	SELECT p.poll_date, t.team_first + ' ' + t.team_last, t.team_abbreviation + '|' + t.team_abbreviation 
	  FROM SportsEditDB.dbo.SMG_Polls AS p
	 INNER JOIN SportsDB.dbo.SMG_Teams AS t ON t.league_key = @league_key
	   AND t.team_abbreviation = p.team_key AND t.season_key = p.season_key
	 WHERE p.league_key = @leagueName AND p.season_key = @seasonKey AND p.week = @week AND p.fixture_key = @fixture_key
	 ORDER BY CAST(p.ranking AS INT)


	-- GISS required fields
 	DECLARE @description					VARCHAR(100)
 	DECLARE @modifiedBy						VARCHAR(100)
	DECLARE @section						VARCHAR(100)
	DECLARE @subsection						VARCHAR(100)
	DECLARE @siteCode						VARCHAR(100)
	DECLARE @surveyAuthorizationModeCode	VARCHAR(100)
 	DECLARE @surveyCode						VARCHAR(100)
 	DECLARE @surveyFormElementTypeCode		VARCHAR(100)
 	DECLARE @surveyQuestionCopy				VARCHAR(100)
 	DECLARE @surveyQuestionGroupTypeCode	VARCHAR(100)
 	DECLARE @surveyQuestionTypeCode			VARCHAR(100)
 	DECLARE @surveyResponseModeCode			VARCHAR(100)
 	DECLARE @surveyResultsModeCode			VARCHAR(100)
 	DECLARE @surveyStatusCode				VARCHAR(100)
 	DECLARE @surveyTypeCode					VARCHAR(100)
 	DECLARE @title							VARCHAR(100)
	DECLARE @calculateSummaryEveryN			INT


	-- Hard code the settings for now...
	SET @description = 'Fan Poll'
 	SET @modifiedBy = 'SMG'
	SET @section = 'sports'
	SET @subsection = @leagueName
	SET @siteCode = 'USAT'
	SET @surveyAuthorizationModeCode = 'PUBLIC'
 	SET @surveyCode = UPPER(@leagueName) + ' ' + @description + ' ' + CAST(@seasonKey AS VARCHAR(4)) + ' Week ' + CAST(@week AS VARCHAR(4))
 	SET @surveyFormElementTypeCode = 'RADIO'
 	SET @surveyQuestionCopy = 'Rank '
 	SET @surveyQuestionGroupTypeCode = 'STANDARD'
 	SET @surveyQuestionTypeCode = 'PICK_ONE'
 	SET @surveyResponseModeCode = 'ONE_RESPONSE'
 	--SET @surveyResponseModeCode = 'PER_SITE'
 	SET @surveyResultsModeCode = 'HIDE_RESULTS'
 	SET @surveyStatusCode = 'ACTIVE'
 	SET @surveyTypeCode = 'SURVEY'
 	SET @title = @description + ' Week ' + CAST(@week AS VARCHAR(4))
	SET @calculateSummaryEveryN = 60


	DECLARE @startDate	DATETIME
	SELECT TOP 1 @startDate = poll_date FROM @answers

	DECLARE @endDate	DATETIME
	--SET @endDate = DATEADD(DD, 3, @startDate)
	SET @endDAte = DATEADD(DD, 3, CAST((CONVERT(VARCHAR(10), @startDate, 120) + ' 00:00') AS DATETIME))


	-- Create the questions table from @maxPolls
	DECLARE @q INT = 1
	DECLARE @questions TABLE (
		surveyId		INT,
		groupId			INT,
	    questionCopy	VARCHAR(100),
	    questionRank	INT,
		questionId		INT,
		poll_date		DATETIME,
	    answerCopy		VARCHAR(100),
	    answerValue		VARCHAR(100),
	    answerRank		INT,
		answerId		INT
	)

	WHILE (@q <= @maxPolls)
	BEGIN
		INSERT INTO @questions (questionRank, questionCopy, answerCopy, answerValue, answerRank, poll_date)
		SELECT @q, @surveyQuestionCopy + CAST(@q AS VARCHAR(4)), answerCopy, answerValue, answerRank, poll_date
		  FROM @answers
		SET @q = @q + 1
	END


   	DECLARE @existing TABLE (
		surveyId		INT,
		groupId			INT,
	    questionRank	INT,
		questionId		INT,
	    answerRank		INT,
		answerId		INT
	)

	INSERT INTO @existing
		   (surveyId, groupId, questionRank, questionId, answerRank, answerId)
	SELECT 
		   node.value('(surveyId/text())[1]', 'int'),
		   node1.value('(surveyQuestionGroupId/text())[1]', 'int'),
		   node2.value('(sortRank/text())[1]', 'int'),
		   node2.value('(surveyQuestionId/text())[1]', 'int'),
		   node3.value('(sortRank/text())[1]', 'int'),
		   node3.value('(surveyAnswerId/text())[1]', 'int')
	  FROM @xmlData.nodes('//root/results/item') AS SMG(node)
	 CROSS APPLY node.nodes('surveyQuestionGroups/item') AS SMG1(node1)
	 CROSS APPLY node1.nodes('surveyQuestions/item') AS SMG2(node2)
	 CROSS APPLY node2.nodes('surveyAnswers/item') AS SMG3(node3)

	UPDATE q
	   SET q.surveyId = e.surveyId, q.groupId = e.groupId, q.questionId = e.questionId, q.answerId = e.answerId
 	  FROM @questions AS q
	 INNER JOIN @existing AS e ON e.questionRank = q.questionRank AND e.answerRank = q.answerRank


	DECLARE @surveyId INT
	DECLARE @groupId INT
	SELECT @surveyId = surveyId, @groupId = groupId FROM @questions GROUP BY surveyId, groupId


	-- Output XML
    ;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
	SELECT
			@surveyId AS surveyId,
			@startDate AS startDate, @endDate AS endDate,
			@calculateSummaryEveryN AS calculateSummaryEveryN,
			@description AS description,
			@modifiedBy AS modifiedBy,
			@section AS section,
			@subsection AS subsection,
			@siteCode AS siteCode,
			@surveyAuthorizationModeCode AS surveyAuthorizationModeCode,
			@surveyCode AS surveyCode,
			--@surveyId AS surveyId,
			@surveyResponseModeCode AS surveyResponseModeCode,
			@surveyResultsModeCode AS surveyResultsModeCode,
			@surveyStatusCode AS surveyStatusCode,
			@surveyTypeCode AS surveyTypeCode,
			@title AS title,
			(
				SELECT	'true' AS 'json:Array',
						1 AS sortRank, @groupId AS surveyQuestionGroupId,
						@surveyQuestionGroupTypeCode AS surveyQuestionGroupTypeCode,
						@title AS surveyQuestionGroupName,
						(
							SELECT
									questionCopy,
									questionRank AS sortRank,
									questionId AS surveyQuestionId,
									@surveyFormElementTypeCode AS surveyFormElementTypeCode,
									@surveyQuestionTypeCode AS surveyQuestionTypeCode,
									(
										SELECT answerCopy, answerValue, answerRank AS sortRank, answerId AS surveyAnswerId
										  FROM @questions AS a
										 WHERE a.questionRank = q.questionRank
										   FOR XML RAW('surveyAnswers'), TYPE
									)
							FROM @questions AS q
							GROUP BY q.questionRank, q.questionCopy, q.questionId
							FOR XML RAW('surveyQuestions'), TYPE
						)
				FOR XML RAW('surveyQuestionGroups'), TYPE
			)
	FOR XML RAW('root'), TYPE

END


GO
