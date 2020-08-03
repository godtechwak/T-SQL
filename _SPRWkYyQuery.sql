IF EXISTS (SELECT * From sysobjects Where id = object_id('_SPRWkYyQuery') AND sysstat & 0xf = 4)
DROP PROCEDURE _SPRWkYyQuery
GO
/*************************************************************************************************    
 설    명 - 연차내역 조회  
 작 성 일 - 
 작 성 자 - 이범확 
*************************************************************************************************/   
CREATE PROCEDURE _SPRWkYyQuery
    @xmlDocument    NVARCHAR(MAX),   -- : 화면의 정보를 xml로 전달
    @xmlFlags       INT = 0,         -- : 해당 xml의 Type
    @ServiceSeq     INT = 0,         -- : 서비스 번호
    @WorkingTag     NVARCHAR(10)= '',-- : WorkingTag
    @CompanySeq     INT = 1,         -- : 회사 번호
    @LanguageSeq    INT = 1,         -- : 언어 번호
    @UserSeq        INT = 0,         -- : 사용자 번호
    @PgmSeq        	INT = 0          -- : 프로그램 번호

AS
    DECLARE @docHandle       INT,
            @PuSeq           INT,
            @PtSeq           INT,
            @DeptSeq         INT,
            @EmpSeq          INT,
            @FromYY          NCHAR(4),   -- 조회기간From
            @ToYY            NCHAR(4),   -- 조회기간To
            @EntRetType	     INT     ,   -- 재직/퇴직구분
            @FromYM          NCHAR(6),   -- 발생년월From
            @ToYM            NCHAR(6),   -- 발생년월To
			@UserEmpSeq      INT			-- UserSeq 기준으로 Empseq 가져오기
		   ,@EmpYyAmtPbSeq   INT
		   ,@CountFromYY     NCHAR(4)
		   ,@CountToYY       NCHAR(4)
           ,@IsDeptOrg		 NVARCHAR(1) -- 하위부서포함
		   ,@SMCmpOccurBegYy INT		 -- #bhlee_20181101
		   ,@SMCmpOccurMm	 NCHAR(2)    -- #bhlee_20181101
		   ,@IsRevisionSum	 NCHAR(1)	 -- #bhlee_20190513
		   ,@PayYM			 NCHAR(6)    -- #bhlee_20190514

    EXEC sp_xml_preparedocument @docHandle OUTPUT, @xmlDocument

    SELECT  @PuSeq         = ISNULL(PuSeq, 0),
            @PtSeq         = ISNULL(PtSeq, 0),
            @DeptSeq       = ISNULL(DeptSeq, 0),
            @EmpSeq        = ISNULL(EmpSeq, 0),
            @FromYY        = ISNULL(FromYY, ''),  
            @ToYY          = ISNULL(ToYY, '')  ,
            @EntRetType    = ISNULL(EntRetType, 0),
            @FromYM        = ISNULL(FromYM, ''),  
            @ToYM          = ISNULL(ToYM, '')   ,
            @IsDeptOrg     = ISNULL(IsDeptOrg, ''),
			@IsRevisionSum = ISNULL(IsRevisionSum, '0'),
			@PayYM		   = ISNULL(PayYM, '')
      FROM OPENXML(@docHandle, N'/ROOT/DataBlock1', @xmlFlags)     
      WITH (PuSeq         INT,
            PtSeq         INT,
            DeptSeq       INT,
            EmpSeq        INT,
            FromYY        NCHAR(4),
            ToYY          NCHAR(4),
            EntRetType    INT,
            FromYM        NCHAR(6),
            ToYM          NCHAR(6),
            IsDeptOrg     NVARCHAR(1),
			IsRevisionSum NCHAR(1),
			PayYM		  NCHAR(6)
           )   
	
	-- 개인연차내역조회 화면이 아닌 연월차내역조회 전체조회 가능한 화면에서 조회 하기 위해 변수 담기
	SELECT @UserEmpSeq = ISNULL(@EmpSeq,0)
	-- 보안이슈로 인해 UserSeq 기준으로 EmpSeq 가져오기
	
	IF @PgmSeq=1637 -- 개인연차 내역조회 화면에서는 UserSeq 기준으로 EmpSeq 가져올수 있도록..
	BEGIN
	EXEC _SCOMGetEssUserEmp @CompanySeq,@userSeq,@UserEmpSeq OUTPUT
	END
	
	SELECT @EmpYyAmtPbSeq    = EmpYyAmtPbSeq
		  ,@SMCmpOccurBegYy = ISNULL(SMCmpOccurBegYy, 0)
		  ,@SMCmpOccurMm     = ISNULL(SMCmpOccurMm, '') 
	  FROM _TPRWkYyMm5Days
     WHERE CompanySeq = @CompanySeq
       AND Seq = 1

    --===================
    -- 년차발생및 사용일수        
    --===================
    CREATE TABLE #YYMM        
    (   YY              NCHAR(4)    NOT NULL,   -- 년도
        EmpSeq          INT         NOT NULL,   -- 사원
        OccurFrDate     NCHAR(8)        NULL,   -- 발생시작일
        OccurToDate     NCHAR(8)        NULL,   -- 발생종료일
        OccurDays       NUMERIC(19, 5)  NULL,   -- 발생일수
        UseDays         DECIMAL(19, 5)  NULL,   -- 사용일수        
        UseFrDate       NCHAR(8)        NULL,   -- 사용시작일        
        UseToDate       NCHAR(8)        NULL,   -- 사용종료일        
        PayYM           NCHAR(6)        NULL,   -- 지급월
        PbSeq           INT             NULL,   -- 급상여종류
        PileDays        NUMERIC(19, 5)  NULL,   -- 이월적치일수
        SumPileDays     NUMERIC(19, 5)  NULL,   -- 적치일수
        GnerAmtYyMm     NCHAR(6)        NULL,   -- 통상임금기준월
        AddDays         NUMERIC(19, 5)  NULL,   -- 추가발생일
        OccurTime       NUMERIC(19, 5)  NULL,   -- 발생시간
        UseTime         NUMERIC(19, 5)  NULL,   -- 사용시간
        PileTime        NUMERIC(19, 5)  NULL,   -- 이월적치시간
        SumPileTime     NUMERIC(19, 5)  NULL,   -- 적치시간
	    RevisionSeq     INT				NULL,   -- 개정여부 #bhlee_20180815
		RevisionDays    NUMERIC(19, 5)  NULL,   -- 개정연차일수	 #bhlee_20190513
		TotOccurDays	NUMERIC(19, 5)  NULL,   -- 총발생일수		 #bhlee_20190513
		IsRevisionSumYY NCHAR(1)		NULL    -- 개정연차합산연도 #bhlee_20190513
	   ,EntYY			NCHAR(4)		NULL
	    
    )        
	CREATE CLUSTERED INDEX YYMM_index ON #YYMM(EmpSeq)

	--===============================
	-- 최종 연차 사용일 수를 담는 테이블
	--===============================
    CREATE TABLE #Use        
    (   YY          NCHAR(4)        NOT NULL,   -- 년도
        EmpSeq      INT             NOT NULL,   -- 사원
        UseDays     NUMERIC(19, 5)      NULL,   -- 사용일수  
        UseTime     NUMERIC(19, 5)      NULL    -- 사용시간 
    )        

	--=================================================================
	-- 2017년 5월 30일 이후 입사자들의 매월 연차 발생연도와 발생일수 담는 테이블
	--=================================================================
	CREATE TABLE #temp
	(
		YY		         NCHAR(4)
	   ,OccurDays        DECIMAL(19, 5)
	   ,EmpSeq	         INT
	   ,Seq			     INT IDENTITY(1, 1)
	   ,RevisionSeq      INT
	   ,IsNotContinueSum NCHAR(1) DEFAULT 1
	   ,UseFrDate		 NCHAR(8)
	   ,UseToDate		 NCHAR(8)
	   ,NextUseFrDate    NCHAR(8)
	   ,NextUseToDate    NCHAR(8)
	)
	CREATE CLUSTERED INDEX temp_index ON #temp(EmpSeq, YY)

	--================================
	-- 사원의 연차 결근일 수를 담는 테이블
	--================================
	CREATE TABLE #EmpUseDays
	(
		YY        NCHAR(4) 
	   ,EmpSeq    INT
	   ,UseDays   DECIMAL(19, 5)
	   ,AbsDate   NCHAR(8)
	   ,WkItemSeq INT -- #bhlee_20181031
	   ,Seq	      INT
	)

	--===============================================
	-- #EmpUseDays 테이블의 데이터를 정제하여 담는 테이블
	--===============================================
	CREATE TABLE #EmpUseDays2
	(
		YY      NCHAR(4) 
	   ,EmpSeq  INT
	   ,UseDays DECIMAL(19, 5)
	   ,AbsDate NCHAR(8)
	   ,WkItemSeq INT -- #bhlee_20181031
	   ,Seq	    INT
	)
	CREATE CLUSTERED INDEX EmpUseDays2_index ON #EmpUseDays2(EmpSeq, Seq) 


	--===============================================
	-- #EmpUseDays 테이블의 데이터를 정제하여 담는 테이블
	--===============================================
	CREATE TABLE #InEmpUseDays
	(
	    YY		NCHAR(4)
	   ,EmpSeq  INT
	   ,UseDate NCHAR(8) 
	   ,UseDays DECIMAL(19, 5)
	   ,WkItemSeq INT -- #bhlee_20181031
	   ,Seq       INT
	)
	CREATE CLUSTERED INDEX InEmpUseDays_index ON #InEmpUseDays(YY, EmpSeq) 
	
	-- 연차발생기준월이 1월이 아니면서 기준연도 -1인 경우
    IF @SMCmpOccurMm <> '1' AND @SMCmpOccurBegYy = 3045001 
	BEGIN
		INSERT INTO #YYMM         
			(YY, EmpSeq, OccurFrDate, OccurToDate, OccurDays, UseDays, UseFrDate, UseToDate, PayYM, PbSeq, PileDays, SumPileDays, GnerAmtYyMm, AddDays, OccurTime, UseTime, PileTime, SumPileTime, RevisionSeq)            
		SELECT A.YY,
			   A.EmpSeq,
			   A.OccurFrDate,
			   A.OccurToDate,
			   ISNULL(A.OccurDays, 0)+ISNULL(A.AddDays, 0),
			   0,
			   A.UseFrDate,
			   A.UseToDate,
			   A.PayYM,
			   A.PbSeq,
			   A.PileDays,
			   ISNULL(A.BasePileDays, 0) + ISNULL(A.AddPileDays, 0),    -- 기본적치일수 + 추가적치일수
			   A.GnerAmtYyMm,
			   A.AddDays AS AddDays,
			   ISNULL(A.OccurTime, 0) + ISNULL(A.AddDays * 8, 0),           -- OccurTime
			   0,                                                           -- UseTime
			   ISNULL(A.PileTime, 0),                                       -- PileTime
			   ISNULL(A.BasePileDays * 8, 0) + ISNULL(A.AddPileDays * 8, 0) -- SumPileTime
			  ,0
		 FROM _TPRWkYyEmpDays AS A WITH(NOLOCK) 
			   LEFT OUTER JOIN _fnAdmEmpOrd(@CompanySeq, '')                AS B ON A.EmpSeq  = B.EmpSeq    
						  JOIN _fnOrgDeptHR(@CompanySeq, 1, @DeptSeq, '')   AS X ON B.DeptSeq = X.DeptSeq
			   JOIN _TDAEmpDate AS C ON C.CompanySeq = A.CompanySeq
											   AND C.EmpSeq     = A.EmpSeq
											   AND C.SMDateType = 3054007
											   AND C.EmpDate    < '20170530'
		WHERE A.CompanySeq = @CompanySeq
		  AND (A.EmpSeq  = @UserEmpSeq OR @UserEmpSeq = 0)  
		  AND (@IsDeptOrg = '1' OR (@IsDeptOrg <> '1' AND (B.DeptSeq = @DeptSeq OR @DeptSeq = 0)))    -- 부서
		  AND (B.PuSeq   = @PuSeq OR @PuSeq = 0)        -- 
		  AND (B.PtSeq   = @PtSeq OR @PtSeq = 0)        -- 
		  AND (@EntRetType = 0 OR (@EntRetType = 3031001 AND B.RetDate = '') OR (@EntRetType = 3031002 AND B.RetDate <> ''))
		  AND (@FromYM = '' OR A.YY + A.ProcMM >= @FromYM)
		  AND (@ToYM = '' OR A.YY + A.ProcMM <= @ToYM)

		INSERT INTO #YYMM         
			(YY, EmpSeq, OccurFrDate, OccurToDate, OccurDays, UseDays, UseFrDate, UseToDate, PayYM, PbSeq, PileDays, SumPileDays, GnerAmtYyMm, AddDays, OccurTime, UseTime, PileTime, SumPileTime, RevisionSeq)            
		SELECT A.YY,
			   A.EmpSeq,
			   A.OccurFrDate,
			   A.OccurToDate,
			   ISNULL(A.OccurDays, 0)+ISNULL(A.AddDays, 0),
			   0,
			   A.UseFrDate,
			   A.UseToDate,
			   A.PayYM,
			   A.PbSeq,
			   A.PileDays,
			   ISNULL(A.BasePileDays, 0) + ISNULL(A.AddPileDays, 0),    -- 기본적치일수 + 추가적치일수
			   A.GnerAmtYyMm,
			   A.AddDays AS AddDays,
			   ISNULL(A.OccurTime, 0) + ISNULL(A.AddDays * 8, 0),           -- OccurTime
			   0,                                                           -- UseTime
			   ISNULL(A.PileTime, 0),                                       -- PileTime
			   ISNULL(A.BasePileDays * 8, 0) + ISNULL(A.AddPileDays * 8, 0) -- SumPileTime
			  ,0
		 FROM _TPRWkYyEmpDays AS A WITH(NOLOCK) 
			   LEFT OUTER JOIN _fnAdmEmpOrd(@CompanySeq, '')                AS B ON A.EmpSeq  = B.EmpSeq   
						  JOIN _fnOrgDeptHR(@CompanySeq, 1, @DeptSeq, '')   AS X ON B.DeptSeq = X.DeptSeq 
						  JOIN _TDAEmpDate AS C ON C.CompanySeq = A.CompanySeq
											   AND C.EmpSeq     = A.EmpSeq
											   AND C.SMDateType = 3054007
											   AND C.EmpDate   >= '20170530'
		WHERE A.CompanySeq = @CompanySeq
		  AND (A.EmpSeq  = @UserEmpSeq OR @UserEmpSeq = 0)  
		  AND (@IsDeptOrg = '1' OR (@IsDeptOrg <> '1' AND (B.DeptSeq = @DeptSeq OR @DeptSeq = 0)))    -- 부서
		  AND (B.PuSeq   = @PuSeq OR @PuSeq = 0)        -- 
		  AND (B.PtSeq   = @PtSeq OR @PtSeq = 0)        -- 
		  AND (@EntRetType = 0 OR (@EntRetType = 3031001 AND B.RetDate = '') OR (@EntRetType = 3031002 AND B.RetDate <> ''))
		  AND (@FromYM = '' OR A.YY + A.ProcMM >= @FromYM)
		  AND (@ToYM = '' OR A.YY + A.ProcMM <= @ToYM)
		  AND (A.YY + ISNULL(A.ProcMM, '') <> LEFT(C.EmpDate, 6) AND A.OccurDays <> 11)
		  AND A.EmpSeq NOT IN (SELECT EmpSeq		
								 FROM _TPRWkYyEmpDaysExProb AS W_Sub1
								WHERE W_Sub1.EmpSeq     = A.EmpSeq
								  AND W_Sub1.YY         = A.YY
								  AND W_Sub1.CompanySeq = A.CompanySeq)
		  AND LEFT(C.EmpDate, 6) < LEFT(C.EmpDate, 4) + CASE WHEN @SMCmpOccurMm IN ('11', '12') THEN CONVERT(NCHAR(2), @SMCmpOccurMm) 
																								ELSE '0' + CONVERT(NCHAR(2), @SMCmpOccurMm) 
																								END

		INSERT INTO #YYMM         
			(YY, EmpSeq, OccurFrDate, OccurToDate, OccurDays, UseDays, UseFrDate, UseToDate, PayYM, PbSeq, PileDays, SumPileDays, GnerAmtYyMm, AddDays, OccurTime, UseTime, PileTime, SumPileTime, RevisionSeq)            
		SELECT A.YY,
			   A.EmpSeq,
			   A.OccurFrDate,
			   A.OccurToDate,
			   ISNULL(A.OccurDays, 0)+ISNULL(A.AddDays, 0),
			   0,
			   A.UseFrDate,
			   A.UseToDate,
			   A.PayYM,
			   A.PbSeq,
			   A.PileDays,
			   ISNULL(A.BasePileDays, 0) + ISNULL(A.AddPileDays, 0),    -- 기본적치일수 + 추가적치일수
			   A.GnerAmtYyMm,
			   A.AddDays AS AddDays,
			   ISNULL(A.OccurTime, 0) + ISNULL(A.AddDays * 8, 0),           -- OccurTime
			   0,                                                           -- UseTime
			   ISNULL(A.PileTime, 0),                                       -- PileTime
			   ISNULL(A.BasePileDays * 8, 0) + ISNULL(A.AddPileDays * 8, 0) -- SumPileTime
			  ,0
		 FROM _TPRWkYyEmpDays AS A WITH(NOLOCK) 
			   LEFT OUTER JOIN _fnAdmEmpOrd(@CompanySeq, '')                AS B ON A.EmpSeq  = B.EmpSeq    
						  JOIN _fnOrgDeptHR(@CompanySeq, 1, @DeptSeq, '')   AS X ON B.DeptSeq = X.DeptSeq 
						  JOIN _TDAEmpDate AS C ON C.CompanySeq        = A.CompanySeq
											   AND C.EmpSeq            = A.EmpSeq
											   AND C.SMDateType		   = 3054007
											   AND C.EmpDate		  >= '20170530'
											   AND LEFT(C.EmpDate ,4) <> A.YY
		WHERE A.CompanySeq = @CompanySeq
		  AND (A.EmpSeq  = @UserEmpSeq OR @UserEmpSeq = 0)  
		  AND (@IsDeptOrg = '1' OR (@IsDeptOrg <> '1' AND (B.DeptSeq = @DeptSeq OR @DeptSeq = 0)))    -- 부서
		  AND (B.PuSeq   = @PuSeq OR @PuSeq = 0)        -- 
		  AND (B.PtSeq   = @PtSeq OR @PtSeq = 0)        -- 
		  AND (@EntRetType = 0 OR (@EntRetType = 3031001 AND B.RetDate = '') OR (@EntRetType = 3031002 AND B.RetDate <> ''))
		  AND (@FromYM = '' OR A.YY + A.ProcMM >= @FromYM)
		  AND (@ToYM = '' OR A.YY + A.ProcMM <= @ToYM)
		  AND LEFT(C.EmpDate, 6) >= LEFT(C.EmpDate, 4) + CASE WHEN @SMCmpOccurMm IN ('11', '12') THEN CONVERT(NCHAR(2), @SMCmpOccurMm) 
																							 	 ELSE '0' + CONVERT(NCHAR(2), @SMCmpOccurMm) 
																								 END
	END
	ELSE 
	BEGIN
		IF @IsDeptOrg = '1' -- 하위부서 포함일 경우
		BEGIN
			INSERT INTO #YYMM         
				(YY, EmpSeq, OccurFrDate, OccurToDate, OccurDays, UseDays, UseFrDate, UseToDate, PayYM, PbSeq, PileDays, SumPileDays, GnerAmtYyMm, AddDays, OccurTime, UseTime, PileTime, SumPileTime, RevisionSeq)            
			SELECT A.YY,
				   A.EmpSeq,
				   A.OccurFrDate,
				   A.OccurToDate,
				   ISNULL(A.OccurDays, 0)+ISNULL(A.AddDays, 0),
				   0,
				   A.UseFrDate,
				   A.UseToDate,
				   A.PayYM,
				   A.PbSeq,
				   A.PileDays,
				   ISNULL(A.BasePileDays, 0) + ISNULL(A.AddPileDays, 0),    -- 기본적치일수 + 추가적치일수
				   A.GnerAmtYyMm,
				   A.AddDays AS AddDays,
				   ISNULL(A.OccurTime, 0) + ISNULL(A.AddDays * 8, 0),           -- OccurTime
				   0,                                                           -- UseTime
				   ISNULL(A.PileTime, 0),                                       -- PileTime
				   ISNULL(A.BasePileDays * 8, 0) + ISNULL(A.AddPileDays * 8, 0) -- SumPileTime
				  ,0
			 FROM _TPRWkYyEmpDays AS A WITH(NOLOCK) 
				   LEFT OUTER JOIN _fnAdmEmpOrd(@CompanySeq, '')                AS B ON A.EmpSeq  = B.EmpSeq    
							  JOIN _fnOrgDeptHR(@CompanySeq, 1, @DeptSeq, '')   AS X ON B.DeptSeq = X.DeptSeq
				   LEFT OUTER JOIN _TDAEmpDate AS C ON C.CompanySeq = A.CompanySeq
												   AND C.EmpSeq     = A.EmpSeq
												   AND C.SMDateType = 3054007
			WHERE A.CompanySeq = @CompanySeq
			  AND (A.EmpSeq  = @UserEmpSeq OR @UserEmpSeq = 0)  
			  AND (@IsDeptOrg = '1' OR (@IsDeptOrg <> '1' AND (B.DeptSeq = @DeptSeq OR @DeptSeq = 0)))    -- 부서
			  AND (B.PuSeq   = @PuSeq OR @PuSeq = 0)        -- 
			  AND (B.PtSeq   = @PtSeq OR @PtSeq = 0)        -- 
			  AND (@EntRetType = 0 OR (@EntRetType = 3031001 AND B.RetDate = '') OR (@EntRetType = 3031002 AND B.RetDate <> ''))
			  AND (@FromYM = '' OR A.YY + A.ProcMM >= @FromYM)
			  AND (@ToYM = '' OR A.YY + A.ProcMM <= @ToYM)
			  AND A.YY NOT IN(SELECT YY
								FROM _TDAEmpDate
							   WHERE SMDateType		   = 3054007
								 AND CompanySeq		   = A.CompanySeq
								 AND EmpSeq			   = A.EmpSeq
								 AND EmpDate		  >= '20170530'
								 AND LEFT(EmpDate, 4)  = A.YY
								 AND @SMCmpOccurBegYy <> 3045002)  
		END
		ELSE -- 하위 부서 미포함일 경우
		BEGIN
			INSERT INTO #YYMM         
				(YY, EmpSeq, OccurFrDate, OccurToDate, OccurDays, UseDays, UseFrDate, UseToDate, PayYM, PbSeq, PileDays, SumPileDays, GnerAmtYyMm, AddDays, OccurTime, UseTime, PileTime, SumPileTime, RevisionSeq)            
			SELECT A.YY,
				   A.EmpSeq,
				   A.OccurFrDate,
				   A.OccurToDate,
				   ISNULL(A.OccurDays, 0)+ISNULL(A.AddDays, 0),
				   0,
				   A.UseFrDate,
				   A.UseToDate,
				   A.PayYM,
				   A.PbSeq,
				   A.PileDays,
				   ISNULL(A.BasePileDays, 0) + ISNULL(A.AddPileDays, 0),    -- 기본적치일수 + 추가적치일수
				   A.GnerAmtYyMm,
				   A.AddDays AS AddDays,
				   ISNULL(A.OccurTime, 0) + ISNULL(A.AddDays * 8, 0),           -- OccurTime
				   0,                                                           -- UseTime
				   ISNULL(A.PileTime, 0),                                       -- PileTime
				   ISNULL(A.BasePileDays * 8, 0) + ISNULL(A.AddPileDays * 8, 0) -- SumPileTime
				  ,0
			 FROM _TPRWkYyEmpDays AS A WITH(NOLOCK) 
				   LEFT OUTER JOIN _fnAdmEmpOrd(@CompanySeq, '')                AS B ON A.EmpSeq  = B.EmpSeq    
				   LEFT OUTER JOIN _TDAEmpDate AS C ON C.CompanySeq = A.CompanySeq
												   AND C.EmpSeq     = A.EmpSeq
												   AND C.SMDateType = 3054007
			WHERE A.CompanySeq = @CompanySeq
			  AND (A.EmpSeq  = @UserEmpSeq OR @UserEmpSeq = 0)  
			  AND (@IsDeptOrg = '1' OR (@IsDeptOrg <> '1' AND (B.DeptSeq = @DeptSeq OR @DeptSeq = 0)))    -- 부서
			  AND (B.PuSeq   = @PuSeq OR @PuSeq = 0)        -- 
			  AND (B.PtSeq   = @PtSeq OR @PtSeq = 0)        -- 
			  AND (@EntRetType = 0 OR (@EntRetType = 3031001 AND B.RetDate = '') OR (@EntRetType = 3031002 AND B.RetDate <> ''))
			  AND (@FromYM = '' OR A.YY + A.ProcMM >= @FromYM)
			  AND (@ToYM = '' OR A.YY + A.ProcMM <= @ToYM)
			  AND A.YY NOT IN(SELECT YY
								FROM _TDAEmpDate
							   WHERE SMDateType		   = 3054007
								 AND CompanySeq		   = A.CompanySeq
								 AND EmpSeq			   = A.EmpSeq
								 AND EmpDate		  >= '20170530'
								 AND LEFT(EmpDate, 4)  = A.YY
								 AND @SMCmpOccurBegYy <> 3045002)
		END
	END	
											
    IF @IsRevisionSum = '0' -- 개정연차합계여부가 '0'일 때
	BEGIN
		IF @IsDeptOrg = '1' -- 하위부서 포함일 경우
		BEGIN
			--===============
			-- 개정연차 대상자
			--===============
			INSERT INTO #YYMM         
				(YY, EmpSeq, OccurFrDate, OccurToDate, OccurDays, UseDays, UseFrDate, UseToDate, PayYM
				,PbSeq, PileDays, SumPileDays, GnerAmtYyMm, AddDays, OccurTime, UseTime, PileTime, SumPileTime, RevisionSeq, EntYY)
			SELECT LEFT(A.YM, 4), A.EmpSeq, MIN(A.OccurFrDate), MAX(A.OccurToDate), SUM(A.OccurDays), 0,  MIN(A.UseFrDate), MAX(A.UseToDate), MAX(A.PayYm)
				  ,MAX(C.PbSeq), 0, 0, MAX(A.PayYm), 0, SUM(A.OccurDays)*8, SUM(A.OccurDays)*8, 0, 0, 1, LEFT(MAX(B.EmpDate), 4)
			  FROM _TPRWkYyEmpDaysExProb AS A
				   JOIN _TDAEmpDate		 AS B ON B.CompanySeq = A.CompanySeq
											 AND B.EmpSeq     = A.EmpSeq
											 AND B.SMDateType = 3054007
											 AND B.EmpDate   >= '20170530'
				   JOIN _TPRWkYyEmpDays  AS C ON C.CompanySeq = B.CompanySeq
											 AND C.EmpSeq     = B.EmpSeq
											 AND C.YY		  = LEFT(B.EmpDate, 4) -- #bhlee_20180820
				   LEFT OUTER JOIN _fnAdmEmpOrd(@CompanySeq, '')              AS Z ON A.EmpSeq  = Z.EmpSeq
							  JOIN _fnOrgDeptHR(@CompanySeq, 1, @DeptSeq, '') AS X ON Z.DeptSeq = X.DeptSeq
			 WHERE A.CompanySeq = @CompanySeq
			   AND (A.EmpSeq  = @UserEmpSeq OR @UserEmpSeq = 0)	-- #bhlee_20181121
			   AND (@IsDeptOrg = '1' OR (@IsDeptOrg <> '1' AND (Z.DeptSeq = @DeptSeq OR @DeptSeq = 0)))    -- 부서
			   AND (Z.PuSeq   = @PuSeq OR @PuSeq = 0)        -- 
			   AND (Z.PtSeq   = @PtSeq OR @PtSeq = 0)        -- 
			   AND (@EntRetType = 0 OR (@EntRetType = 3031001 AND Z.RetDate = '') OR (@EntRetType = 3031002 AND Z.RetDate <> ''))
			   AND (@FromYM = '' OR A.YM >= @FromYM)
			   AND (@ToYM = ''   OR A.YM <= @ToYM)
			 GROUP BY LEFT(A.YM, 4), A.EmpSeq
		END
		ELSE -- 하위부서 포함이 아닐 경우
		BEGIN
			--===============
			-- 개정연차 대상자
			--===============
			INSERT INTO #YYMM         
				(YY, EmpSeq, OccurFrDate, OccurToDate, OccurDays, UseDays, UseFrDate, UseToDate, PayYM
				,PbSeq, PileDays, SumPileDays, GnerAmtYyMm, AddDays, OccurTime, UseTime, PileTime, SumPileTime, RevisionSeq, EntYY)
			SELECT LEFT(A.YM, 4), A.EmpSeq, MIN(A.OccurFrDate), MAX(A.OccurToDate), SUM(A.OccurDays), 0,  MIN(A.UseFrDate), MAX(A.UseToDate), MAX(A.PayYm)
				  ,MAX(C.PbSeq), 0, 0, MAX(A.PayYm), 0, SUM(A.OccurDays)*8, SUM(A.OccurDays)*8, 0, 0, 1, LEFT(MAX(B.EmpDate), 4)
			  FROM _TPRWkYyEmpDaysExProb AS A
				   JOIN _TDAEmpDate		 AS B ON B.CompanySeq = A.CompanySeq
											 AND B.EmpSeq     = A.EmpSeq
											 AND B.SMDateType = 3054007
											 AND B.EmpDate   >= '20170530'
				   JOIN _TPRWkYyEmpDays  AS C ON C.CompanySeq = B.CompanySeq
											 AND C.EmpSeq     = B.EmpSeq
											 AND C.YY		  = LEFT(B.EmpDate, 4) -- #bhlee_20180820
				   LEFT OUTER JOIN _fnAdmEmpOrd(@CompanySeq, '')              AS Z ON A.EmpSeq  = Z.EmpSeq
			 WHERE A.CompanySeq = @CompanySeq
			   AND (A.EmpSeq  = @UserEmpSeq OR @UserEmpSeq = 0)	-- #bhlee_20181121
			   AND (@IsDeptOrg = '1' OR (@IsDeptOrg <> '1' AND (Z.DeptSeq = @DeptSeq OR @DeptSeq = 0)))    -- 부서
			   AND (Z.PuSeq   = @PuSeq OR @PuSeq = 0)        -- 
			   AND (Z.PtSeq   = @PtSeq OR @PtSeq = 0)        -- 
			   AND (@EntRetType = 0 OR (@EntRetType = 3031001 AND Z.RetDate = '') OR (@EntRetType = 3031002 AND Z.RetDate <> ''))
			   AND (@FromYM = '' OR A.YM >= @FromYM)
			   AND (@ToYM = ''   OR A.YM <= @ToYM)
			 GROUP BY LEFT(A.YM, 4), A.EmpSeq
		END

		-- 개정연차 적치일수를 반영하기 위한 업데이트문 #bhlee_20190610
		UPDATE #YYMM
		   SET SumPileDays = ISNULL(B.BasePileDays, 0) + ISNULL(B.AddPileDays, 0)
		  FROM #YYMM AS A
			   JOIN (SELECT MIN(Sub_B1.YY)	         AS YY
						   ,Sub_B1.EmpSeq		     AS EmpSeq
						   ,MAX(Sub_B2.BasePileDays) AS BasePileDays
						   ,MAX(Sub_B2.AddPileDays)  AS AddPileDays
				       FROM #YYMM AS Sub_B1
						    JOIN _TPRWkYyEmpDays AS Sub_B2 ON Sub_B2.EmpSeq           = Sub_B1.EmpSeq
														  AND Sub_B2.YY               = CASE WHEN (SELECT MIN(YY) 
																									 FROM #YYMM 
																									WHERE EmpSeq	  = Sub_B1.EmpSeq
																									  AND YY          = Sub_B1.YY
																									  AND RevisionSeq = 1) <> Sub_B1.EntYY THEN Sub_B1.EntYY
																							 ELSE Sub_B1.YY
																						END
							JOIN _TDAEmpDate	 AS Sub_B3 ON Sub_B3.EmpSeq           = Sub_B2.EmpSeq		
												          AND Sub_B3.CompanySeq       = Sub_B2.CompanySeq
												          AND Sub_B3.SMDateType       = 3054007
												          AND Sub_B3.EmpDate         >= '20170530'
												          AND LEFT(Sub_B3.EmpDate, 4) = Sub_B2.YY
				      WHERE Sub_B2.CompanySeq = @CompanySeq
				      GROUP BY Sub_B1.EmpSeq) AS B ON B.EmpSeq = A.EmpSeq
												  AND B.YY     = A.YY
		 WHERE A.RevisionSeq = 1 -- #bhlee_20200407 
     END
	 ELSE -- 개정연차합계여부가 '1'일 때	
	 BEGIN
		 --===============
		 -- 개정연차 대상자
		 --===============
		 INSERT INTO #YYMM         
			 (YY, EmpSeq, OccurFrDate, OccurToDate, OccurDays, UseDays, UseFrDate, UseToDate, PayYM
			 ,PbSeq, PileDays, SumPileDays, GnerAmtYyMm, AddDays, OccurTime, UseTime, PileTime, SumPileTime, RevisionSeq)
		 SELECT LEFT(A.YM, 4), A.EmpSeq, MIN(A.OccurFrDate), MAX(A.OccurToDate), SUM(A.OccurDays), 0,  MIN(A.UseFrDate), MAX(A.UseToDate), MAX(A.PayYm)
			   ,MAX(C.PbSeq), 0, 0, MAX(A.PayYm), 0, SUM(A.OccurDays)*8, SUM(A.OccurDays)*8, 0, 0, 1
		   FROM _TPRWkYyEmpDaysExProb AS A
			    JOIN _TDAEmpDate	  AS B ON B.CompanySeq = A.CompanySeq
										  AND B.EmpSeq     = A.EmpSeq
										  AND B.SMDateType = 3054007
										  AND B.EmpDate   >= '20170530'
			    JOIN _TPRWkYyEmpDays  AS C ON C.CompanySeq = B.CompanySeq
										  AND C.EmpSeq     = B.EmpSeq
										  AND C.YY		   = LEFT(B.EmpDate, 4) -- #bhlee_20180820
		   LEFT JOIN _fnAdmEmpOrd(@CompanySeq, '') AS Z ON A.EmpSeq  = Z.EmpSeq
		  WHERE A.CompanySeq = @CompanySeq
		    AND (A.EmpSeq  = @UserEmpSeq OR @UserEmpSeq = 0)	-- #bhlee_20181121
		    AND (@IsDeptOrg = '1' OR (@IsDeptOrg <> '1' AND (Z.DeptSeq = @DeptSeq OR @DeptSeq = 0)))    -- 부서
		    AND (Z.PuSeq   = @PuSeq OR @PuSeq = 0)        -- 
		    AND (Z.PtSeq   = @PtSeq OR @PtSeq = 0)        -- 
		    AND (@EntRetType = 0 OR (@EntRetType = 3031001 AND Z.RetDate = '') OR (@EntRetType = 3031002 AND Z.RetDate <> ''))
		    AND (@FromYM = '' OR A.YM >= @FromYM)
		    AND (@ToYM = ''   OR A.YM <= @ToYM)
		  GROUP BY LEFT(A.YM, 4), A.EmpSeq
		  HAVING LEFT(A.YM, 4) IN (SELECT MIN(YY) AS YY
								   FROM #YYMM
								  WHERE EmpSeq      = A.EmpSeq
									AND RevisionSeq = 0
								  GROUP BY EmpSeq) 

	 	 INSERT INTO #YYMM         
		 	 (YY, EmpSeq, OccurFrDate, OccurToDate, OccurDays, UseDays, UseFrDate, UseToDate, PayYM
			 ,PbSeq, PileDays, SumPileDays, GnerAmtYyMm, AddDays, OccurTime, UseTime, PileTime, SumPileTime, RevisionSeq)
		 SELECT LEFT(A.YM, 4), A.EmpSeq, MIN(A.OccurFrDate), MAX(A.OccurToDate), SUM(A.OccurDays), 0,  MIN(A.UseFrDate), MAX(A.UseToDate), MAX(A.PayYm)
			   ,MAX(C.PbSeq), 0, 0, MAX(A.PayYm), 0, SUM(A.OccurDays)*8, SUM(A.OccurDays)*8, 0, 0, 1
		   FROM _TPRWkYyEmpDaysExProb AS A
			    JOIN _TDAEmpDate	  AS B ON B.CompanySeq = A.CompanySeq
										  AND B.EmpSeq     = A.EmpSeq
										  AND B.SMDateType = 3054007
										  AND B.EmpDate   >= '20170530'
			    JOIN _TPRWkYyEmpDays  AS C ON C.CompanySeq = B.CompanySeq
										  AND C.EmpSeq     = B.EmpSeq
										  AND C.YY		   = LEFT(B.EmpDate, 4) -- #bhlee_20180820
		   LEFT JOIN _fnAdmEmpOrd(@CompanySeq, '') AS Z ON A.EmpSeq  = Z.EmpSeq
		  WHERE A.CompanySeq = @CompanySeq
		    AND (A.EmpSeq  = @UserEmpSeq OR @UserEmpSeq = 0)	-- #bhlee_20181121
		    AND (@IsDeptOrg = '1' OR (@IsDeptOrg <> '1' AND (Z.DeptSeq = @DeptSeq OR @DeptSeq = 0)))    -- 부서
		    AND (Z.PuSeq   = @PuSeq OR @PuSeq = 0)        -- 
		    AND (Z.PtSeq   = @PtSeq OR @PtSeq = 0)        -- 
		    AND (@EntRetType = 0 OR (@EntRetType = 3031001 AND Z.RetDate = '') OR (@EntRetType = 3031002 AND Z.RetDate <> ''))
		    AND (@FromYM = '' OR A.YM >= @FromYM)
		    AND (@ToYM = ''   OR A.YM <= @ToYM)
			AND A.EmpSeq NOT IN (SELECT EmpSeq FROM #YYMM WHERE EmpSeq = A.EmpSeq)
		  GROUP BY LEFT(A.YM, 4), A.EmpSeq
	 END
     
	IF @IsDeptOrg = '1' -- 하위부서 포함일 경우
	BEGIN
		--============================================= 
		-- [입사자연차발생처리] 화면을 사용하는 경우의 대상자
		--=============================================
		INSERT INTO #YYMM(YY, EmpSeq, OccurFrDate, OccurToDate, OccurDays, UseDays, UseFrDate, UseToDate, PayYM,
						  PbSeq, PileDays, SumPileDays, GnerAmtYyMm, AddDays, OccurTime, UseTime, PileTime, SumPileTime, RevisionSeq)
		SELECT Z.YY,
			   Z.EmpSeq,
			   Z.OccurFrDate,
			   Z.OccurToDate,
			   ISNULL(Z.OccurDays, 0)+ISNULL(Z.AddDays, 0),
			   0,
			   Z.UseFrDate,
			   Z.UseToDate,
			   Z.PayYM,
			   Z.PbSeq,
			   Z.PileDays,
			   ISNULL(Z.BasePileDays, 0) + ISNULL(Z.AddPileDays, 0),    -- 기본적치일수 + 추가적치일수
			   Z.GnerAmtYyMm,
			   Z.AddDays AS AddDays,
			   ISNULL(Z.OccurTime, 0) + ISNULL(Z.AddDays * 8, 0),           -- OccurTime
			   0,                                                           -- UseTime
			   ISNULL(Z.PileTime, 0),                                       -- PileTime
			   ISNULL(z.BasePileDays * 8, 0) + ISNULL(Z.AddPileDays * 8, 0) -- SumPileTime
			  ,1
		  FROM _TPRWkYyEmpDays AS Z
			LEFT OUTER JOIN _fnAdmEmpOrd(@CompanySeq, '')               AS B ON Z.EmpSeq  = B.EmpSeq
					  JOIN _fnOrgDeptHR(@CompanySeq, 1, @DeptSeq, '')   AS X ON B.DeptSeq = X.DeptSeq
		 WHERE Z.EmpSeq IN (SELECT A.EmpSeq 
							FROM _TPRWkYyEmpDays  AS A 
								 JOIN _TDAEmpDate AS B ON B.CompanySeq = A.CompanySeq 
													  AND B.EmpSeq	 = A.EmpSeq 
													  AND B.SMDateType = 3054007
													  AND B.EmpDate   >= '20170530'
						   WHERE A.YY + A.ProcMM = LEFT(B.EmpDate, 6)
							 AND NOT EXISTS(SELECT * FROM _TPRWkYyEmpDaysExProb WHERE CompanySeq = A.CompanySeq AND EmpSeq = A.EmpSeq)
						 )
		   AND NOT EXISTS(SELECT * FROM #YYMM WHERE Z.YY = YY AND Z.EmpSeq = EmpSeq)
		   AND (@UserEmpSeq = 0 OR @UserEmpSeq = Z.EmpSeq) -- #bhlee_20181121
		   AND (@IsDeptOrg = '1' OR (@IsDeptOrg <> '1' AND (B.DeptSeq = @DeptSeq OR @DeptSeq = 0)))    -- 부서
		   AND (B.PuSeq   = @PuSeq OR @PuSeq = 0)        -- 
		   AND (B.PtSeq   = @PtSeq OR @PtSeq = 0)        -- 
		   AND (@EntRetType = 0 OR (@EntRetType = 3031001 AND B.RetDate = '') OR (@EntRetType = 3031002 AND B.RetDate <> ''))
		   AND (@FromYM = '' OR Z.YY + Z.ProcMM >= @FromYM)
		   AND (@ToYM   = '' OR Z.YY + Z.ProcMM <= @ToYM)
		   AND Z.CompanySeq = @CompanySeq
	END
	ELSE -- 하위부서 포함이 아닐경우
	BEGIN 
		--============================================= 
		-- [입사자연차발생처리] 화면을 사용하는 경우의 대상자
		--=============================================
		INSERT INTO #YYMM(YY, EmpSeq, OccurFrDate, OccurToDate, OccurDays, UseDays, UseFrDate, UseToDate, PayYM,
						  PbSeq, PileDays, SumPileDays, GnerAmtYyMm, AddDays, OccurTime, UseTime, PileTime, SumPileTime, RevisionSeq)
		SELECT Z.YY,
			   Z.EmpSeq,
			   Z.OccurFrDate,
			   Z.OccurToDate,
			   ISNULL(Z.OccurDays, 0)+ISNULL(Z.AddDays, 0),
			   0,
			   Z.UseFrDate,
			   Z.UseToDate,
			   Z.PayYM,
			   Z.PbSeq,
			   Z.PileDays,
			   ISNULL(Z.BasePileDays, 0) + ISNULL(Z.AddPileDays, 0),    -- 기본적치일수 + 추가적치일수
			   Z.GnerAmtYyMm,
			   Z.AddDays AS AddDays,
			   ISNULL(Z.OccurTime, 0) + ISNULL(Z.AddDays * 8, 0),           -- OccurTime
			   0,                                                           -- UseTime
			   ISNULL(Z.PileTime, 0),                                       -- PileTime
			   ISNULL(z.BasePileDays * 8, 0) + ISNULL(Z.AddPileDays * 8, 0) -- SumPileTime
			  ,1
		  FROM _TPRWkYyEmpDays AS Z
			LEFT OUTER JOIN _fnAdmEmpOrd(@CompanySeq, '')               AS B ON Z.EmpSeq  = B.EmpSeq
		 WHERE Z.EmpSeq IN (SELECT A.EmpSeq 
							FROM _TPRWkYyEmpDays  AS A 
								 JOIN _TDAEmpDate AS B ON B.CompanySeq = A.CompanySeq 
													  AND B.EmpSeq	 = A.EmpSeq 
													  AND B.SMDateType = 3054007
													  AND B.EmpDate   >= '20170530'
						   WHERE A.YY + A.ProcMM = LEFT(B.EmpDate, 6)
							 AND NOT EXISTS(SELECT * FROM _TPRWkYyEmpDaysExProb WHERE CompanySeq = A.CompanySeq AND EmpSeq = A.EmpSeq)
						 )
		   AND NOT EXISTS(SELECT * FROM #YYMM WHERE Z.YY = YY AND Z.EmpSeq = EmpSeq)
		   AND (@UserEmpSeq = 0 OR @UserEmpSeq = Z.EmpSeq) -- #bhlee_20181121
		   AND (@IsDeptOrg = '1' OR (@IsDeptOrg <> '1' AND (B.DeptSeq = @DeptSeq OR @DeptSeq = 0)))    -- 부서
		   AND (B.PuSeq   = @PuSeq OR @PuSeq = 0)        -- 
		   AND (B.PtSeq   = @PtSeq OR @PtSeq = 0)        -- 
		   AND (@EntRetType = 0 OR (@EntRetType = 3031001 AND B.RetDate = '') OR (@EntRetType = 3031002 AND B.RetDate <> ''))
		   AND (@FromYM = '' OR Z.YY + Z.ProcMM >= @FromYM)
		   AND (@ToYM   = '' OR Z.YY + Z.ProcMM <= @ToYM)
		   AND Z.CompanySeq = @CompanySeq
	END


	 INSERT INTO #temp(YY, OccurDays, EmpSeq, RevisionSeq, UseFrDate, UseToDate)
	 SELECT A.YY, A.OccurDays, A.EmpSeq, A.RevisionSeq, A.UseFrDate, A.UseToDate
	   FROM #YYMM			 AS A
		    JOIN _TDAEmpDate AS B ON B.CompanySeq = @CompanySeq
								 AND B.EmpSeq     = A.EmpSeq
								 AND B.SMDateType = 3054007
								 AND B.EmpDate   >= '20170530'
	  ORDER BY A.EmpSeq, A.YY, A.RevisionSeq DESC
	  
	DECLARE @Count1         INT      -- 변동 카운트 값
	       ,@Max1	        INT      -- 최대 카운트 값
		   ,@PresentYear    NCHAR(4) -- 현재 카운트 연도
		   ,@NextYear	    NCHAR(4) -- 다음 카운트 연도
		   ,@PreviousEmpSeq INT		 -- 이전 카운트 사원코드
		   ,@PresentEmpSeq  INT	     -- 현재 카운트 사원코드
		   ,@NextEmpSeq     INT      -- 다음 카운트 사원코드
 
     INSERT INTO #EmpUseDays(YY, EmpSeq, UseDays, AbsDate, WkItemSeq)
	 SELECT A.YY
		   ,A.EmpSeq
		   ,CASE WHEN ISNULL(B.IsHalf, '0') = '1' THEN 0.5
                 WHEN ISNULL(B.IsHalf, '0') = '2' THEN 0.25 ELSE 1.0 END
		   ,B.AbsDate
		   ,B.WkItemSeq
      FROM #YYMM	  AS A
		   JOIN #temp		 AS A1			   ON A1.EmpSeq     = A.EmpSeq
           JOIN _TPRWkAbsEmp AS B WITH(NOLOCK) ON A.EmpSeq      = B.EmpSeq
                                              AND B.AbsDate    >= A.UseFrDate
                                              AND B.AbsDate    <= A.UseToDate
                                              AND B.CompanySeq  = @CompanySeq
           JOIN _TPRWkItem   AS C WITH(NOLOCK) ON B.WkItemSeq   = C.WkItemSeq
                                              AND B.CompanySeq  = C.CompanySeq
	                                          AND C.SMAbsWkSort = 3069002 -- 년차

	INSERT INTO #EmpUseDays2(EmpSeq, UseDays, AbsDate, WkItemSeq, Seq)
	SELECT EmpSeq, UseDays, AbsDate, WkItemSeq, ROW_NUMBER()OVER(ORDER BY EmpSeq, AbsDate, WkItemSeq)
	  FROM #EmpUseDays 
	 GROUP BY EmpSeq, AbsDate, UseDays, WkItemSeq
	 ORDER BY EmpSeq, ROW_NUMBER()OVER(ORDER BY EmpSeq, AbsDate, WkItemSeq)												
	

   DECLARE @Count2   INT            -- 변동 카운트 값
		  ,@Max2	 INT		    -- 최대 카운트 값
		  ,@VarYear  NCHAR(4)	    -- 변동 연도 값
		  ,@MaxYear  NCHAR(4)       -- 최대 연도 값
		  ,@UseDays  DECIMAL(19, 5) -- 연차사용일 수 변수
		  ,@UseDays2 DECIMAL(19, 5) -- 연차사용일 수 변수2
		  ,@MaxSeq2  INT
		   
	SELECT @Count2  = 1
          ,@Max2    = (SELECT COUNT(*) FROM #EmpUseDays2)
		  ,@VarYear = (SELECT MIN(YY)  FROM #YYMM WHERE RevisionSeq = 1)
		  ,@MaxYear = (SELECT MAX(YY)  FROM #YYMM WHERE RevisionSeq = 1)

	SELECT @UseDays = 0
	
	WHILE(@VarYear <= @MaxYear) 
		BEGIN
			WHILE(@Count2 <= @Max2)
			BEGIN
				SELECT @PresentEmpSeq  = (SELECT EmpSeq   FROM #EmpUseDays2 WHERE Seq    = @Count2)
					  ,@NextEmpSeq	   = (SELECT EmpSeq   FROM #EmpUseDays2 WHERE Seq    = @Count2 + 1)

				-- @UseDays2는 @UseDays를 개정연차에 사용한 일자로 판단하지 않았지만 차후 카운팅되는 결근일자가 현재의 연차 사용기간에 포함될 경우에는 리카운팅을 하기 위해 존재하는 변수이다.
				IF @UseDays <> -1
				BEGIN
					SELECT @UseDays2 = @UseDays
				END
				
				SELECT @UseDays = CASE WHEN @UseDays = -1 THEN (CASE WHEN EXISTS(SELECT * -- CASE 1 START, CASE 1_Sub START
																				   FROM #temp
																			      WHERE EmpSeq      = A.EmpSeq
																				    AND YY          = @VarYear
																				    AND RevisionSeq = 1) THEN (CASE WHEN (SELECT OccurDays -- CASE 3_Sub START 개정적용연차 발생일수와 사용일수가 같을 때
																															FROM #temp
																														   WHERE EmpSeq      = A.EmpSeq
																															 AND YY          = @VarYear
																															 AND RevisionSeq = 1) = @UseDays2 THEN (CASE WHEN NOT EXISTS(SELECT * -- CASE 4_Sub START
																																														   FROM #temp
																																														  WHERE EmpSeq      = @PresentEmpSeq
																																														    AND RevisionSeq = 1
																																															AND YY          = CONVERT(NCHAR(4), DATEADD(YEAR, 1, @VarYear), 112)
																																															AND AbsDate BETWEEN UseFrDate AND UseToDate)
																																										      AND
																																											  NOT EXISTS (SELECT *
																																															FROM #temp
																																														   WHERE EmpSeq      = @PresentEmpSeq
																																									 						 AND RevisionSeq = 0
																																									 						 AND YY			 = @VarYear
																																									 						 AND AbsDate BETWEEN UseFrDate AND UseToDate) 
																																											  AND 
																																											  NOT EXISTS (SELECT * 
																																															FROM #temp
																																														   WHERE EmpSeq      = @PresentEmpSeq
																																									 						 AND RevisionSeq = 0
																																									 						 AND YY			 = CONVERT(NCHAR(4), DATEADD(YEAR, 1, @VarYear), 112)
																																									 						 AND AbsDate BETWEEN UseFrDate AND UseToDate) THEN @UseDays2 + A.UseDays 
																																										 ELSE -1
																																									END) -- CASE 4_Sub END
																											        WHEN (SELECT OccurDays -- 개정적용연차 발생일수가 사용일수보다 작을 때
																														    FROM #temp
																														   WHERE EmpSeq		 = A.EmpSeq
																														     AND YY			 = @VarYear
																														     AND RevisionSeq = 1) < @UseDays2 THEN (CASE WHEN EXISTS (SELECT * -- CASE 5_Sub START
																																														FROM #temp
																																													   WHERE EmpSeq      = @PresentEmpSeq
																																														 AND RevisionSeq = 1
																																								 						 AND YY			 = CONVERT(NCHAR(4), DATEADD(YEAR, 1, @VarYear), 112)
																																														 AND AbsDate BETWEEN UseFrDate AND UseToDate)
																																											  OR
																																											  EXISTS (SELECT * 
																																												        FROM #temp
																																													   WHERE EmpSeq      = @PresentEmpSeq
																																														 AND RevisionSeq = 0
																																								 						 AND YY			 = @VarYear
																																														 AND AbsDate BETWEEN UseFrDate AND UseToDate)
																																											  OR 
																																											  EXISTS (SELECT * 
																																													    FROM #temp
																																													   WHERE EmpSeq      = @PresentEmpSeq
																																														 AND RevisionSeq = 0
																																								 					     AND YY			 = CONVERT(NCHAR(4), DATEADD(YEAR, 1, @VarYear), 112)
																																														 AND AbsDate BETWEEN UseFrDate AND UseToDate) THEN -1
																																									    ELSE @UseDays2 + A.UseDays
																																								   END) -- CASE 5_Sub END
																												    WHEN (SELECT OccurDays -- 개정적용연차 발생일수가 사용일수보다 클 때
																															FROM #temp
																														   WHERE EmpSeq      = A.EmpSeq
																														 	 AND YY		     = @VarYear
																															 AND RevisionSeq = 1) > @UseDays2 THEN (CASE WHEN @UseDays2 + 0.5 = (SELECT OccurDays -- CASE 6_Sub2 START 0.5일을 더한 사용일수가 발생일수와 같을 때	
																																																  FROM #temp
																																																 WHERE EmpSeq      = A.EmpSeq
																																																   AND YY          = @VarYear
																																																   AND RevisionSeq = 1) THEN (CASE WHEN A.UseDays = 0.5 THEN @UseDays2 + A.UseDays -- CASE 7_Sub START 다음 사용연차가 반차일 경우
																																																								   ELSE (CASE WHEN NOT EXISTS (SELECT * -- CASE 8_Sub START
																																																																 FROM #temp
																																																																WHERE EmpSeq      = @PresentEmpSeq
																																																										  						  AND RevisionSeq = 1
																																																										  						  AND YY		  = CONVERT(NCHAR(4), DATEADD(YEAR, 1, @VarYear), 112)
																																																																  AND AbsDate BETWEEN UseFrDate AND UseToDate)
																																																												   AND
																																																												   NOT EXISTS (SELECT * 
																																																																 FROM #temp
																																																																WHERE EmpSeq      = @PresentEmpSeq
																																																									 							  AND RevisionSeq = 0
																																																									 							  AND YY		  = @VarYear
																																																																  AND AbsDate BETWEEN UseFrDate AND UseToDate)
																																																												   AND 
																																																												   NOT EXISTS (SELECT *
																																																																 FROM #temp
																																																																WHERE EmpSeq      = @PresentEmpSeq
																																																									 							  AND RevisionSeq = 0
																																																									 							  AND YY		  = CONVERT(NCHAR(4), DATEADD(YEAR, 1, @VarYear), 112)
																																																																  AND AbsDate BETWEEN UseFrDate AND UseToDate) THEN @UseDays2 + A.UseDays
																																																											  ELSE -1
																																																										 END) -- CASE 8_Sub END
																																																							  END) -- CASE 7_Sub END
																																										 WHEN @UseDays2 + 0.5 <> (SELECT OccurDays
																																																   FROM #temp
																																																  WHERE EmpSeq      = A.EmpSeq
																																																	AND YY          = @VarYear
																																																	AND RevisionSeq = 1) THEN @UseDays2 + A.UseDays
																																									END) -- CASE 6_Sub END
																									           END) -- CASE 3_Sub END
																	 WHEN EXISTS(SELECT * -- 회계연도연차일 때
																				   FROM #temp
																				  WHERE EmpSeq      = A.EmpSeq
																				    AND YY          = @VarYear
																					AND RevisionSeq = 0) THEN (CASE WHEN (SELECT OccurDays -- CASE 9_Sub START 회계연차 발생일수와 사용일수가 같을 때
																															FROM #temp
																														   WHERE EmpSeq      = A.EmpSeq
																															 AND YY          = @VarYear
																															 AND RevisionSeq = 0) = @UseDays2 THEN (CASE WHEN NOT EXISTS (SELECT * -- CASE 10_Sub START
																																														    FROM #temp
																																														   WHERE EmpSeq      = @PresentEmpSeq
																																															 AND RevisionSeq = 0
																																															 AND YY			 = CONVERT(NCHAR(4), DATEADD(YEAR, 1, @VarYear), 112)
																																															 AND AbsDate BETWEEN UseFrDate AND UseToDate)
																																											  AND 
																																											  NOT EXISTS (SELECT * 
																																														    FROM #temp
																																														   WHERE EmpSeq      = @PresentEmpSeq
																																															 AND RevisionSeq = 1
																																															 AND YY			 = @VarYear
																																															 AND AbsDate BETWEEN UseFrDate AND UseToDate)
																																											  AND 
																																											  NOT EXISTS (SELECT * 
																																														    FROM #temp
																																														   WHERE EmpSeq      = @PresentEmpSeq
																																															 AND RevisionSeq = 1
																																															 AND YY			 = CONVERT(NCHAR(4), DATEADD(YEAR, 1, @VarYear), 112)
																																															 AND AbsDate BETWEEN UseFrDate AND UseToDate) THEN @UseDays2 + A.UseDays 
																																										 ELSE -1
																																									END) -- CASE 10_Sub END
																													WHEN (SELECT OccurDays -- 회계연차 발생일수가 사용일수보다 작을 때
																															FROM #temp
																														   WHERE EmpSeq      = A.EmpSeq
																															 AND YY          = @VarYear
																															 AND RevisionSeq = 0) < @UseDays2 THEN (CASE WHEN EXISTS (SELECT * -- CASE 11_Sub START
																																													    FROM #temp
																																													   WHERE EmpSeq      = @PresentEmpSeq
																																														 AND RevisionSeq = 0
																																														 AND YY			 = CONVERT(NCHAR(4), DATEADD(YEAR, 1, @VarYear), 112)
																																														 AND AbsDate BETWEEN UseFrDate AND UseToDate)
																																											  OR 
																																											  EXISTS (SELECT *
																																													    FROM #temp
																																													   WHERE EmpSeq      = @PresentEmpSeq
																																														 AND RevisionSeq = 1
																																														 AND YY			= @VarYear
																																														 AND AbsDate BETWEEN UseFrDate AND UseToDate)
																																											  OR 
																																											  EXISTS (SELECT * 
																																													    FROM #temp
																																													   WHERE EmpSeq      = @PresentEmpSeq
																																													 	 AND RevisionSeq = 1
																																							    						 AND YY			= CONVERT(NCHAR(4), DATEADD(YEAR, 1, @VarYear), 112)
																																														 AND AbsDate BETWEEN UseFrDate AND UseToDate) THEN -1
																																										 ELSE @UseDays2 + A.UseDays
																																								    END) -- CASE 11_Sub END
																													WHEN (SELECT OccurDays -- 회계연차 발생일수가 사용일수보다 클 때
																															FROM #temp
																														   WHERE EmpSeq      = A.EmpSeq
																															 AND YY          = @VarYear
																															 AND RevisionSeq = 0) > @UseDays2 THEN (CASE WHEN @UseDays2 + 0.5 = (SELECT OccurDays -- CASE 12_Sub START 0.5일을 더한 사용일수가 발생일수와 같을 때	
																																																   FROM #temp
																																																  WHERE EmpSeq      = A.EmpSeq
																																																    AND YY          = @VarYear
																																																    AND RevisionSeq = 0) THEN (CASE WHEN A.UseDays = 0.5 THEN @UseDays2 + A.UseDays -- CASE 13_Sub START 다음 사용연차가 반차일 경우
																																																								    ELSE (CASE WHEN NOT EXISTS (SELECT * -- CASE 14_Sub START
																																																																  FROM #temp
																																																															     WHERE EmpSeq        = @PresentEmpSeq
																																																										 						   AND RevisionSeq   = 0
																																																										 						   AND YY			 = CONVERT(NCHAR(4), DATEADD(YEAR, 1, @VarYear), 112)
																																																																   AND AbsDate BETWEEN UseFrDate AND UseToDate)
																																																												    AND 
																																																												    NOT EXISTS (SELECT * 
																																																																  FROM #temp
																																																															     WHERE EmpSeq      = @PresentEmpSeq
																																																										 						   AND RevisionSeq = 1
																																																										 						   AND YY		   = @VarYear
																																																																   AND AbsDate BETWEEN UseFrDate AND UseToDate)
																																																												    AND 
																																																												    NOT EXISTS (SELECT * 
																																																																  FROM #temp
																																																															     WHERE EmpSeq        = @PresentEmpSeq
																																																										 						   AND RevisionSeq   = 1
																																																										 						   AND YY			 = CONVERT(NCHAR(4), DATEADD(YEAR, 1, @VarYear), 112)
																																																																   AND AbsDate BETWEEN UseFrDate AND UseToDate) THEN @UseDays2 + A.UseDays
																																																											   ELSE -1
																																																										  END) -- CASE 14_Sub END
																																																							   END) -- CASE 13_Sub END 
																																										WHEN @UseDays2 + 0.5 <> (SELECT OccurDays
																																																   FROM #temp
																																																  WHERE EmpSeq      = A.EmpSeq
																																																    AND YY          = @VarYear
																																																    AND RevisionSeq = 0) THEN @UseDays2 + A.UseDays
																																								    END) -- CASE 12_Sub END
																											   END) -- CASE 9_Sub END
															    END) -- CASE 1_Sub END
									   ELSE (CASE WHEN EXISTS(SELECT * -- CASE 2 START 개정적용연차일 때
													            FROM #temp
													           WHERE EmpSeq      = A.EmpSeq
													             AND YY          = @VarYear
													             AND RevisionSeq = 1) THEN (CASE WHEN (SELECT OccurDays -- CASE 3 START 개정적용연차 발생일수와 사용일수가 같을 때
																									     FROM #temp
																									    WHERE EmpSeq      = A.EmpSeq 
																									      AND YY          = @VarYear
																									      AND RevisionSeq = 1) = @UseDays THEN (CASE WHEN NOT EXISTS (SELECT * -- CASE 4 START
																																									   FROM #temp
																																									  WHERE EmpSeq      = @PresentEmpSeq
																																										AND RevisionSeq = 1
																																										AND YY			= CONVERT(NCHAR(4), DATEADD(YEAR, 1, @VarYear), 112)
																																										AND AbsDate BETWEEN UseFrDate AND UseToDate)
																																						  AND
																																						  NOT EXISTS (SELECT *
																																									    FROM #temp
																																									   WHERE EmpSeq      = @PresentEmpSeq
																																									 	 AND RevisionSeq = 0
																																									 	 AND YY			 = @VarYear
																																									 	 AND AbsDate BETWEEN UseFrDate AND UseToDate)
																																						  AND 
																																						  NOT EXISTS (SELECT * 
																																									    FROM #temp
																																									   WHERE EmpSeq      = @PresentEmpSeq
																																									 	 AND RevisionSeq = 0
																																									 	 AND YY			 = CONVERT(NCHAR(4), DATEADD(YEAR, 1, @VarYear), 112)
																																									 	 AND AbsDate BETWEEN UseFrDate AND UseToDate) THEN @UseDays + A.UseDays 
																																				     ELSE (CASE WHEN (SELECT COUNT(*) FROM #temp WHERE EmpSeq = @PresentEmpSeq) = 1 THEN @UseDays + A.UseDays
																																							    ELSE -1
																																						   END)
																																			    END) -- CASE 4 END
																							     WHEN (SELECT OccurDays -- 개정적용연차 발생일수가 사용일수보다 작을 때
																									     FROM #temp
																									    WHERE EmpSeq      = A.EmpSeq
																									      AND YY		  = @VarYear
																									      AND RevisionSeq = 1) < @UseDays THEN (CASE WHEN EXISTS (SELECT * -- CASE 5 START
																																								    FROM #temp
																																								   WHERE EmpSeq      = @PresentEmpSeq
																																								     AND RevisionSeq = 1
																																								 	 AND YY			 = CONVERT(NCHAR(4), DATEADD(YEAR, 1, @VarYear), 112)
																																									 AND AbsDate BETWEEN UseFrDate AND UseToDate)
																																						  OR
																																						  EXISTS (SELECT * 
																																								    FROM #temp
																																								   WHERE EmpSeq      = @PresentEmpSeq
																																								     AND RevisionSeq = 0
																																								 	 AND YY			 = @VarYear
																																									 AND AbsDate BETWEEN UseFrDate AND UseToDate)
																																						  OR 
																																						  EXISTS (SELECT * 
																																								    FROM #temp
																																								   WHERE EmpSeq      = @PresentEmpSeq
																																								     AND RevisionSeq = 0
																																								 	 AND YY			 = CONVERT(NCHAR(4), DATEADD(YEAR, 1, @VarYear), 112)
																																									 AND AbsDate BETWEEN UseFrDate AND UseToDate) THEN -1
																																			         ELSE @UseDays + A.UseDays
																																			    END) -- CASE 5 END
																							     WHEN (SELECT OccurDays -- 개정적용연차 발생일수가 사용일수보다 클 때
																							             FROM #temp
																									    WHERE EmpSeq      = A.EmpSeq
																									      AND YY		  = @VarYear
																									      AND RevisionSeq = 1) > @UseDays THEN (CASE WHEN @UseDays + 0.5 = (SELECT OccurDays -- CASE 6 START 0.5일을 더한 사용일수가 발생일수와 같을 때	
																																										      FROM #temp
																																										     WHERE EmpSeq      = A.EmpSeq
																																										       AND YY          = @VarYear
																																										       AND RevisionSeq = 1) THEN (CASE WHEN A.UseDays = 0.5 THEN @UseDays + A.UseDays -- CASE 7 START 다음 사용연차가 반차일 경우
																																																			   ELSE (CASE WHEN NOT EXISTS (SELECT * -- CASE 8 START
																																																										     FROM #temp
																																																										    WHERE EmpSeq      = @PresentEmpSeq
																																																										  	  AND RevisionSeq = 1
																																																										  	  AND YY		  = CONVERT(NCHAR(4), DATEADD(YEAR, 1, @VarYear), 112)
																																																											  AND AbsDate BETWEEN UseFrDate AND UseToDate)
																																																							   AND
																																																							   NOT EXISTS (SELECT * 
																																																											 FROM #temp
																																																										    WHERE EmpSeq      = @PresentEmpSeq
																																																									 		  AND RevisionSeq = 0
																																																									 		  AND YY		  = @VarYear
																																																											  AND AbsDate BETWEEN UseFrDate AND UseToDate)
																																																							   AND 
																																																							   NOT EXISTS (SELECT *
																																																											 FROM #temp
																																																										    WHERE EmpSeq      = @PresentEmpSeq
																																																									 		  AND RevisionSeq = 0
																																																									 		  AND YY		  = CONVERT(NCHAR(4), DATEADD(YEAR, 1, @VarYear), 112)
																																																											  AND AbsDate BETWEEN UseFrDate AND UseToDate) THEN @UseDays + A.UseDays
																																																					      ELSE -1
																																																				     END) -- CASE 8 END
																																																	      END) -- CASE 7 END
																																				     WHEN @UseDays + 0.5 <> (SELECT OccurDays
																																										       FROM #temp
																																										      WHERE EmpSeq      = A.EmpSeq
																																										        AND YY          = @VarYear
																																											    AND RevisionSeq = 1) THEN CASE WHEN EXISTS(SELECT * 
																																																							 FROM #InEmpUseDays 
																																																							WHERE UseDate   = A.AbsDate
																																																							  AND EmpSeq    = A.EmpSeq
																																																							  AND WkItemSeq = A.WkItemSeq) THEN @UseDays
																																																			   ELSE @UseDays + A.UseDays
																																																		  END
																																			    END) -- CASE 6 END
																				            END) -- CASE 3 END
									              WHEN EXISTS(SELECT * -- 회계연도연차일 때
													            FROM #temp
															   WHERE EmpSeq     = A.EmpSeq
																AND YY          = @VarYear
																AND RevisionSeq = 0) THEN (CASE WHEN (SELECT OccurDays -- CASE 9 START 회계연차 발생일수와 사용일수가 같을 때
																							            FROM #temp
																									   WHERE EmpSeq      = A.EmpSeq
																									     AND YY          = @VarYear
																									     AND RevisionSeq = 0) = @UseDays THEN (CASE WHEN NOT EXISTS (SELECT * -- CASE 10 START
																																									   FROM #temp
																																									  WHERE EmpSeq      = @PresentEmpSeq
																																									    AND RevisionSeq = 0
																																										AND YY = CONVERT(NCHAR(4), DATEADD(YEAR, 1, @VarYear), 112)
																																										AND AbsDate BETWEEN UseFrDate AND UseToDate)
																																						 AND 
																																						 NOT EXISTS (SELECT * 
																																									   FROM #temp
																																									  WHERE EmpSeq      = @PresentEmpSeq
																																									    AND RevisionSeq = 1
																																										AND YY			= @VarYear
																																										AND AbsDate BETWEEN UseFrDate AND UseToDate)
																																						 AND 
																																						 NOT EXISTS (SELECT * 
																																									   FROM #temp
																																									  WHERE EmpSeq      = @PresentEmpSeq
																																									    AND RevisionSeq = 1
																																										AND YY			= CONVERT(NCHAR(4), DATEADD(YEAR, 1, @VarYear), 112)
																																										AND AbsDate BETWEEN UseFrDate AND UseToDate) THEN @UseDays + A.UseDays 
																																				    ELSE -1
																																	           END) -- CASE 10 END
																							    WHEN (SELECT OccurDays -- 회계연차 발생일수가 사용일수보다 작을 때
																									    FROM #temp
																									   WHERE EmpSeq      = A.EmpSeq
																									     AND YY          = @VarYear
																									     AND RevisionSeq = 0) < @UseDays THEN (CASE WHEN EXISTS (SELECT * -- CASE 11 START
																																								   FROM #temp
																																								  WHERE EmpSeq      = @PresentEmpSeq
																																								    AND RevisionSeq = 0
																																									AND YY			= CONVERT(NCHAR(4), DATEADD(YEAR, 1, @VarYear), 112)
																																									AND AbsDate BETWEEN UseFrDate AND UseToDate)
																																						 OR 
																																						 EXISTS (SELECT *
																																								   FROM #temp
																																								  WHERE EmpSeq      = @PresentEmpSeq
																																								    AND RevisionSeq = 1
																																									AND YY			= @VarYear
																																									AND AbsDate BETWEEN UseFrDate AND UseToDate)
																																						 OR 
																																						 EXISTS (SELECT * 
																																							       FROM #temp
																																							      WHERE EmpSeq      = @PresentEmpSeq
																																							        AND RevisionSeq = 1
																																							    	AND YY			= CONVERT(NCHAR(4), DATEADD(YEAR, 1, @VarYear), 112)
																																									AND AbsDate BETWEEN UseFrDate AND UseToDate) THEN -1
																																				    ELSE @UseDays + A.UseDays
																																			   END) -- CASE 11 END
																							    WHEN (SELECT OccurDays -- 회계연차 발생일수가 사용일수보다 클 때
																									    FROM #temp
																									   WHERE EmpSeq      = A.EmpSeq
																									     AND YY          = @VarYear
																									     AND RevisionSeq = 0) > @UseDays THEN (CASE WHEN @UseDays + 0.5 = (SELECT OccurDays -- CASE 12 START 0.5일을 더한 사용일수가 발생일수와 같을 때	
																																										     FROM #temp
																																										    WHERE EmpSeq      = A.EmpSeq
																																											  AND YY          = @VarYear
																																											  AND RevisionSeq = 0) THEN (CASE WHEN A.UseDays = 0.5 THEN @UseDays + A.UseDays -- CASE 13 START 다음 사용연차가 반차일 경우
																																																			  ELSE (CASE WHEN NOT EXISTS (SELECT * -- CASE 14 START
																																																										    FROM #temp
																																																										   WHERE EmpSeq      = @PresentEmpSeq
																																																										 	 AND RevisionSeq = 0
																																																										 	 AND YY			 = CONVERT(NCHAR(4), DATEADD(YEAR, 1, @VarYear), 112)
																																																											 AND AbsDate BETWEEN UseFrDate AND UseToDate)
																																																							  AND 
																																																							  NOT EXISTS (SELECT * 
																																																										    FROM #temp
																																																										   WHERE EmpSeq      = @PresentEmpSeq
																																																										 	 AND RevisionSeq = 1
																																																										 	 AND YY			 = @VarYear
																																																											 AND AbsDate BETWEEN UseFrDate AND UseToDate)
																																																							  AND 
																																																							  NOT EXISTS (SELECT * 
																																																										    FROM #temp
																																																										   WHERE EmpSeq      = @PresentEmpSeq
																																																										 	 AND RevisionSeq = 1
																																																										 	 AND YY			 = CONVERT(NCHAR(4), DATEADD(YEAR, 1, @VarYear), 112)
																																																											 AND AbsDate BETWEEN UseFrDate AND UseToDate) THEN @UseDays + A.UseDays
																																																					     ELSE -1
																																																				    END) -- CASE 14 END
																																																	     END) -- CASE 13 END 
																																				    WHEN @UseDays + 0.5 <> (SELECT OccurDays
																																											  FROM #temp
																																										     WHERE EmpSeq      = A.EmpSeq
																																											   AND YY          = @VarYear
																																											   AND RevisionSeq = 0) THEN @UseDays + A.UseDays
																																			   END) -- CASE 12 END
																						   END) -- CASE 9 END
								             END) -- CASE 2 END
				                  END -- CASE 1 END
			  FROM #EmpUseDays2 AS A
			 WHERE Seq = @Count2

			    IF @UseDays <> -1 -- 매월발생연차에 사용된 일자를 담는다.
			    BEGIN
					INSERT INTO #InEmpUseDays(YY, EmpSeq, UseDate, UseDays, WkItemSeq, Seq)
					SELECT @VarYear, A.EmpSeq, A.AbsDate, A.UseDays, A.WkItemSeq, A.Seq
					  FROM #EmpUseDays2 AS A
					 WHERE A.Seq = @Count2
					   AND NOT EXISTS(SELECT *
										FROM #InEmpUseDays
									   WHERE UseDate   = A.AbsDate
										 AND EmpSeq    = A.EmpSeq
										 AND WkItemSeq = A.WkItemSeq) 
					   AND EXISTS (SELECT *
									 FROM #YYMM
									WHERE @VarYear    = YY
									  AND RevisionSeq = 1
									  AND EmpSeq      = A.EmpSeq
									  AND A.AbsDate BETWEEN UseFrDate AND UseToDate)
					IF @@ROWCOUNT = 0 
					BEGIN
						IF NOT EXISTS(SELECT * FROM #EmpUseDays2 AS A
											  WHERE A.Seq = @Count2
											    AND EXISTS(SELECT *
															 FROM #InEmpUseDays
															WHERE UseDate   = A.AbsDate
															  AND EmpSeq    = A.EmpSeq
															  AND WkItemSeq = A.WkItemSeq))
									
						BEGIN
							SELECT @UseDays = 0
						END
					END
			    END
			

				-- 현재 카운트 사원코드와 다음 카운트 사원코드가 일치하지 않는 경우 사용일 수를 0으로 초기화
			    IF @PresentEmpSeq <> @NextEmpSeq
			    BEGIN
				    SELECT @UseDays = 0
			    END
				
			    SELECT @Count2 = @Count2 + 1
		    END
		
		    SELECT @UseDays = 0
			      ,@Count2  = 0
		    SELECT @VarYear = CONVERT(NCHAR(4), DATEADD(YEAR, 1, @VarYear), 112)
    END



    --================================================================================================================================
    -- 년차사용        
    --================================================================================================================================
	
	INSERT INTO #Use
        (YY, EmpSeq, UseDays, UseTime)         
	
	-- 2017년 05월 30일 이후 입사자
    SELECT A.YY, 
           A.EmpSeq,  
           SUM(CASE WHEN ISNULL(B.IsHalf, '0') = '1' THEN 0.5
                    WHEN ISNULL(B.IsHalf, '0') = '2' THEN 0.25 ELSE 1.0 END) ,
           SUM(CASE WHEN ISNULL(B.IsHalf, '0') = '1' THEN 4  
                    WHEN ISNULL(B.IsHalf, '0') = '2' THEN 2    ELSE 8    END)
      FROM #YYMM AS A
           INNER JOIN _TPRWkAbsEmp AS B WITH(NOLOCK) ON A.EmpSeq = B.EmpSeq
                                                    AND B.AbsDate >= A.UseFrDate
                                                    AND B.AbsDate <= A.UseToDate
                                                    AND B.CompanySeq = @CompanySeq
           INNER JOIN _TPRWkItem   AS C WITH(NOLOCK) ON B.WkItemSeq = C.WkItemSeq
                                                    AND B.CompanySeq = C.CompanySeq
                                                    AND C.SMAbsWkSort = 3069002 -- 년차
		   INNER JOIN _TDAEmpDate  AS D WITH(NOLOCK)ON D.CompanySeq = @CompanySeq
												   AND D.EmpSeq		= A.EmpSeq
												   AND D.SMDateType = 3054007
	 WHERE B.AbsDate NOT IN(SELECT AbsDate FROM #InEmpUseDays WHERE EmpSeq = A.EmpSeq AND UseDate = B.AbsDate) -- 매월발생연차에 사용된 일자는 제외 #bhlee_20180815
	   AND D.EmpDate >= '20170530'
	   AND A.RevisionSeq = 0
     GROUP BY A.YY, A.EmpSeq

	 UNION ALL

	-- 2017년 05월 30일 이전 입사자
	SELECT A.YY, 
           A.EmpSeq,  
           SUM(CASE WHEN ISNULL(B.IsHalf, '0') = '1' THEN 0.5
                    WHEN ISNULL(B.IsHalf, '0') = '2' THEN 0.25 ELSE 1.0 END) ,
           SUM(CASE WHEN ISNULL(B.IsHalf, '0') = '1' THEN 4  
                    WHEN ISNULL(B.IsHalf, '0') = '2' THEN 2    ELSE 8    END)
      FROM #YYMM AS A	
           INNER JOIN _TPRWkAbsEmp AS B WITH(NOLOCK) ON A.EmpSeq = B.EmpSeq
                                                    AND B.AbsDate >= A.UseFrDate
                                                    AND B.AbsDate <= A.UseToDate
                                                    AND B.CompanySeq = @CompanySeq
           INNER JOIN _TPRWkItem   AS C WITH(NOLOCK) ON B.WkItemSeq = C.WkItemSeq
                                                    AND B.CompanySeq = C.CompanySeq
                                                    AND C.SMAbsWkSort = 3069002 -- 년차
		   INNER JOIN _TDAEmpDate  AS D WITH(NOLOCK)ON D.CompanySeq = @CompanySeq
												   AND D.EmpSeq		= A.EmpSeq
												   AND D.SMDateType = 3054007
	 WHERE D.EmpDate < '20170530'
     GROUP BY A.YY, A.EmpSeq        
	
    --================================================================================================================================
    -- 사용일수 update        
    --================================================================================================================================
    -- 회계기준 연차 사용일 수 업데이트
    UPDATE #YYMM         
       SET UseDays = ISNULL(B.UseDays, 0), 
           UseTime = ISNULL(B.UseTime, 0)
      FROM #YYMM AS A
           INNER JOIN #Use AS B ON A.YY = B.YY 
                               AND A.EmpSeq = B.EmpSeq
	 WHERE A.RevisionSeq = 0
	  
	-- 매월발생연차 사용일 수 업데이트 #bhlee_20180815
	UPDATE #YYMM         
       SET UseDays = ISNULL(B.UseDays, 0)
      FROM #YYMM AS A
		   JOIN (SELECT SUM(S2.UseDays) AS UseDays
					   ,S1.EmpSeq
					   ,S1.YY
				   FROM #YYMM			   AS S1
					    JOIN #InEmpUseDays AS S2 ON S2.YY	  = S1.YY
											    AND S2.EmpSeq = S1.EmpSeq
				  WHERE S1.RevisionSeq = 1
				  GROUP BY S1.YY, S1.EmpSeq) AS B ON B.YY	  = A.YY
												 AND B.EmpSeq = A.EmpSeq
	 WHERE (A.RevisionSeq = 1 OR @IsRevisionSum = '1')

	--#bhlee_20190513 
	IF @IsRevisionSum = '0' -- 개정연차합계여부가 '0'일 경우
	BEGIN
		IF @PgmSeq = 1637 -- #bhlee_20180816 (개인연차내역조회 분개)
		BEGIN
			--================================================================================================================================
			-- 년차기준
			--================================================================================================================================
			SELECT MAX(A.YY)         AS YY,          -- 기준년도
				   '0'				 AS IsRevision, -- 개정적용연차여부 #bhlee_20180815
				   MAX(B.EmpName)    AS EmpName,     -- 성명
				   MAX(A.EmpSeq)     AS EmpSeq,      -- 사원코드
				   MAX(B.EmpID)      AS EmpID,       -- 사번
				   MAX(B.DeptName)   AS DeptName,    -- 소속부서
				   MAX(B.UMJpName)   AS UMJpName,    -- 직위
				   MAX(B.UMPgName)   AS UMPgName,    -- 직급
				   MAX(B.UMJoName)   AS UMJoName,    -- 직종
				   MAX(B.PuName)     AS PuName,      -- 급여작업군
				   MAX(B.PtName)     AS PtName,      -- 급여형태명
				   MAX(B.DeptSeq)    AS DeptSeq,     -- 소속부서코드
				   MAX(B.PuSeq)      AS PuSeq,       -- 급여작업군코드
				   MAX(B.PtSeq)      AS PtSeq,       -- 급여형태일련번호
				   MAX(B.EntDate)    AS EntDate,     -- 입사일
				   MAX(B.RetDate)    AS RetireDate,  -- 퇴사일 
				   (SELECT EmpDate FROM _TDAEmpDate WITH(NOLOCK) WHERE CompanySeq = @CompanySeq AND EmpSeq = A.EmpSeq AND SMDateType = 3054007) AS EmpDate,    -- 기산일자
				   MIN(A.OccurFrDate)    AS OccurFrDate, -- 발생기준시작일
				   MAX(A.OccurToDate)    AS OccurToDate, -- 발생기준종료일
				   ISNULL(SUM(A.PileDays), 0) AS PileDays,-- 이월적치일수
				   ISNULL(SUM(A.OccurDays), 0) AS OccurDays,   -- 발생일수
				   ISNULL(SUM(A.UseDays), 0)        AS UseDays,     -- 사용일수
				   ISNULL(SUM(A.SumPileDays), 0)    AS SumPileDays, -- 적치일수계
				   (ISNULL(SUM(A.PileDays), 0) + ISNULL(SUM(A.OccurDays), 0)) - (ISNULL(SUM(A.UseDays), 0) + ISNULL(SUM(A.SumPileDays), 0) ) AS PayDays,-- 
				   MIN(A.UseFrDate)      AS UseFrDate,   -- 사용시작일
				   MAX(A.UseToDate)      AS UseToDate,   -- 사용종료일
				   (ISNULL(SUM(A.PileDays), 0) + ISNULL(SUM(A.OccurDays), 0)) - (ISNULL(SUM(A.UseDays),0) + ISNULL(SUM(A.SumPileDays), 0)) AS BalanceDays,-- 잔여일수
				   ''          AS PayYM,       -- 실지급월
				   '' AS PbName,   -- 지급급상여
				   0          AS PbSeq,       -- 급상여구분
				   ''    AS GnerAmtYyMm, -- 통상임금기준월
				   ISNULL(SUM(A.AddDays), 0)        AS AddDays    , -- 추가발생일
				   0    AS OccurTime  ,  -- 발생시간
				   0    AS UseTime    ,  -- 사용시간
				   0    AS PileTime   ,  -- 이월적치시간
				   0    AS SumPileTime,  -- 적치시간
				   0 AS BalanceTime,  -- 잔여시간
				   ISNULL(MAX(C.EmpDate),'')        AS GrpEntDate,   -- 그룹입사일
				   ISNULL(MAX(E.BizUnitName),'')    AS BizUnitName,  -- 사업부문
				   ISNULL(MAX(F.AccUnitName), '')   AS AccUnitName   -- 회계단위    
			 FROM #YYMM										      AS A 
				  LEFT OUTER JOIN _fnAdmEmpOrd(@CompanySeq, '')   AS B			    ON A.EmpSeq = B.EmpSeq
				  LEFT OUTER JOIN _TDAEmpDate					  AS C WITH(NOLOCK) ON C.CompanySeq = @CompanySeq 
																				   AND A.EmpSeq     = C.EmpSeq
																				   AND C.SMDateType = 3054001		    
				  LEFT OUTER JOIN _TDADept						  AS D WITH(NOLOCK) ON D.CompanySeq = @CompanySeq 
																				   AND B.DeptSeq    = D.DeptSeq 
				  LEFT OUTER JOIN _TDAbizunit					  AS E WITH(NOLOCK) ON D.CompanySeq = E.CompanySeq 
																				   AND D.BizUnit    = E.BizUnit				    
				  LEFT OUTER JOIN _TDAAccUnit					  AS F WITH(NOLOCK) ON D.CompanySeq = F.CompanySeq 
																				   AND D.AccUnit    = F.AccUnit   
			WHERE (@FromYY  = '' OR A.YY = @FromYY)				 --  #bhlee_20180817
			  AND (A.EmpSeq = @UserEmpSeq AND @UserEmpSeq <>  0) -- #bhlee_20181121
			GROUP BY A.EmpSeq
			ORDER BY MAX(A.YY), MAX(B.DeptName), MAX(B.EmpName) DESC
		END
		ELSE
		BEGIN
			--================================================================================================================================
			-- 년차기준
			--================================================================================================================================
			SELECT A.YY         AS YY,          -- 기준년도
				   CONVERT(NCHAR(1), A.RevisionSeq) AS IsRevision, -- 개정적용연차여부 #bhlee_20180815
				   B.EmpName    AS EmpName,     -- 성명
				   A.EmpSeq     AS EmpSeq,      -- 사원코드
				   B.EmpID      AS EmpID,       -- 사번
				   B.DeptName   AS DeptName,    -- 소속부서
				   B.UMJpName   AS UMJpName,    -- 직위
				   B.UMPgName   AS UMPgName,    -- 직급
				   B.UMJoName   AS UMJoName,    -- 직종
				   B.PuName     AS PuName,      -- 급여작업군
				   B.PtName     AS PtName,      -- 급여형태명
				   B.DeptSeq    AS DeptSeq,     -- 소속부서코드
				   B.PuSeq      AS PuSeq,       -- 급여작업군코드
				   B.PtSeq      AS PtSeq,       -- 급여형태일련번호
				   B.EntDate    AS EntDate,     -- 입사일
				   B.RetDate    AS RetireDate,  -- 퇴사일 
				   (SELECT EmpDate FROM _TDAEmpDate WITH(NOLOCK) WHERE CompanySeq = @CompanySeq AND EmpSeq = A.EmpSeq AND SMDateType = 3054007) AS EmpDate,    -- 기산일자
				   A.OccurFrDate    AS OccurFrDate, -- 발생기준시작일
				   A.OccurToDate    AS OccurToDate, -- 발생기준종료일
				   ISNULL(A.PileDays, 0) AS PileDays,-- 이월적치일수
				   ISNULL(A.OccurDays, 0) AS OccurDays,   -- 발생일수
				   A.UseDays        AS UseDays,     -- 사용일수
				   A.SumPileDays    AS SumPileDays, -- 적치일수계
				   (ISNULL(A.PileDays, 0) + ISNULL(A.OccurDays, 0)) - (ISNULL(A.UseDays, 0) + ISNULL(A.SumPileDays, 0) ) AS PayDays,-- 
				   A.UseFrDate      AS UseFrDate,   -- 사용시작일
				   A.UseToDate      AS UseToDate,   -- 사용종료일
				   (ISNULL(A.PileDays, 0) + ISNULL(A.OccurDays, 0)) - (ISNULL(A.UseDays,0) + ISNULL(A.SumPileDays, 0)) AS BalanceDays,-- 잔여일수
				   A.PayYM          AS PayYM,       -- 실지급월
				   (SELECT PbName FROM _TPRBasPb WITH(NOLOCK) WHERE CompanySeq = @CompanySeq AND PbSeq = A.PbSeq) AS PbName,   -- 지급급상여
				   A.PbSeq          AS PbSeq,       -- 급상여구분
				   A.GnerAmtYyMm    AS GnerAmtYyMm, -- 통상임금기준월
				   A.AddDays        AS AddDays    , -- 추가발생일
				   ISNULL(A.OccurTime   ,0)    AS OccurTime  ,  -- 발생시간
				   ISNULL(A.UseTime     ,0)    AS UseTime    ,  -- 사용시간
				   ISNULL(A.PileTime    ,0)    AS PileTime   ,  -- 이월적치시간
				   ISNULL(A.SumPileTime ,0)    AS SumPileTime,  -- 적치시간
				   (ISNULL(A.PileTime, 0) + ISNULL(A.OccurTime, 0)) - (ISNULL(A.UseTime, 0) + ISNULL(A.SumPileTime, 0)) AS BalanceTime,  -- 잔여시간
				   ISNULL(C.EMPDATE,'')        AS GrpEntDate,   -- 그룹입사일
				   ISNULL(E.BizUnitName,'')    AS BizUnitName,  -- 사업부문
				   ISNULL(F.AccUnitName, '')   AS AccUnitName   -- 회계단위      
			 FROM #YYMM										                    AS A 
				  LEFT OUTER JOIN _fnAdmEmpOrd(@CompanySeq, '')                 AS B			  ON A.EmpSeq     = B.EmpSeq
				  LEFT OUTER JOIN _TDAEmpDate					                AS C WITH(NOLOCK) ON C.CompanySeq = @CompanySeq 
																                				 AND A.EmpSeq     = C.EmpSeq
																                				 AND C.SMDateType = 3054001		    
				  LEFT OUTER JOIN _TDADept						                AS D WITH(NOLOCK) ON D.CompanySeq = @CompanySeq 
																                				 AND B.DeptSeq    = D.DeptSeq 
				  LEFT OUTER JOIN _TDAbizunit					                AS E WITH(NOLOCK) ON D.CompanySeq = E.CompanySeq 
																                				 AND D.BizUnit    = E.BizUnit				    
				  LEFT OUTER JOIN _TDAAccUnit					                AS F WITH(NOLOCK) ON D.CompanySeq = F.CompanySeq 
																                				 AND D.AccUnit    = F.AccUnit   
                        
			WHERE (@FromYY = ''     OR A.YY  >= @FromYY)
			  AND (@ToYY   = ''     OR A.YY  <= @ToYY  )
			  AND (A.PayYM = @PayYM	OR @PayYM = ''     ) -- #bhlee_20190514
			ORDER BY A.YY, B.DeptName, B.EmpName, A.RevisionSeq DESC 
		END
	END
    ELSE -- 개정연차합계여부가 '1'일 경우
	BEGIN
		UPDATE #YYMM
		   SET IsRevisionSumYY = '1'
		  FROM #YYMM AS A 
		 WHERE A.RevisionSeq = 0
		   AND A.EmpSeq IN (SELECT EmpSeq
							  FROM _TDAEmpDate 
							 WHERE SMDateType = 3054007
							   AND EmpDate   >= '20170530'
							   AND EmpSeq     = A.EmpSeq
							   AND CompanySeq = @CompanySeq)
		   AND A.YY IN (SELECT MIN(YY) AS YY
						  FROM #YYMM
						 WHERE EmpSeq      = A.EmpSeq
						   AND RevisionSeq = 0
						 GROUP BY EmpSeq)

	    -- 당해입사로 개정연차밖에 존재하지 않을 경우에는 발생일수 0일의 연차데이터를 임의로 생성.
		INSERT INTO #YYMM(YY, EmpSeq, OccurFrDate, OccurToDate, OccurDays, UseDays, UseFrDate, UseToDate, 
						  PayYM, PbSeq, PileDays, SumPileDays, GnerAmtYyMm, AddDays, OccurTime, UseTime, 
						  PileTime, SumPileTime, RevisionSeq, RevisionDays, TotOccurDays, IsRevisionSumYY)
		SELECT YY,       EmpSeq,      OccurFrDate, OccurToDate, 0,			 0,       UseFrDate, UseToDate, 
		       PayYM,    PbSeq,       PileDays,    SumPileDays, GnerAmtYyMm, AddDays, OccurTime, UseTime, 
			   PileTime, SumPileTime, 0, 0, 0, 1
		  FROM #YYMM AS A 
		 WHERE NOT EXISTS (SELECT YY
							 FROM #YYMM AS B
						    WHERE RevisionSeq = 0
							  AND A.EmpSeq    = EmpSeq
							  AND YY		  = (SELECT DATEADD(YEAR, 1, LEFT(EmpDate, 4))
												   FROM _TDAEmpDate AS C
												  WHERE C.EmpSeq      = B.EmpSeq
												    AND C.SMDateType  = 3054007
													AND C.CompanySeq  = @CompanySeq
													AND C.EmpDate    >= '20170530')
						  )
		   AND RevisionSeq = 1

		SELECT A.YY         AS YY,          -- 기준년도
			   CASE WHEN ISNULL(A.IsRevisionSumYY, '0') = '0' THEN '0'	
					ELSE '1'	
			   END	        AS IsRevision, -- 개정적용연차여부 #bhlee_20180815
			   B.EmpName    AS EmpName,     -- 성명
			   A.EmpSeq     AS EmpSeq,      -- 사원코드
			   B.EmpID      AS EmpID,       -- 사번
			   B.DeptName   AS DeptName,    -- 소속부서
			   B.UMJpName   AS UMJpName,    -- 직위
			   B.UMPgName   AS UMPgName,    -- 직급
			   B.UMJoName   AS UMJoName,    -- 직종
			   B.PuName     AS PuName,      -- 급여작업군
			   B.PtName     AS PtName,      -- 급여형태명
			   B.DeptSeq    AS DeptSeq,     -- 소속부서코드
			   B.PuSeq      AS PuSeq,       -- 급여작업군코드
			   B.PtSeq      AS PtSeq,       -- 급여형태일련번호
			   B.EntDate    AS EntDate,     -- 입사일
			   B.RetDate    AS RetireDate,  -- 퇴사일 
			   (SELECT EmpDate FROM _TDAEmpDate WITH(NOLOCK) WHERE CompanySeq = @CompanySeq AND EmpSeq = A.EmpSeq AND SMDateType = 3054007) AS EmpDate,    -- 기산일자
			   A.OccurFrDate		  AS OccurFrDate, -- 발생기준시작일
			   A.OccurToDate          AS OccurToDate, -- 발생기준종료일
			   CASE WHEN ISNULL(A.IsRevisionSumYY, '0') = '0' THEN ISNULL(A.PileDays, 0)
					ELSE ISNULL(A.PileDays, 0) + ISNULL(X.Revision_PileDays, 0) 
			   END AS PileDays,    -- 이월적치일수
			   CASE WHEN ISNULL(A.IsRevisionSumYY, '0') = '0' THEN 0
				    ELSE ISNULL(X.Revision_OccurDays, 0)   
			   END AS RevisionDays, -- 개정연차일수 #bhlee_20190513
			   ISNULL(A.OccurDays, 0) AS OccurDays,	   -- 발생일수 
			   CASE WHEN ISNULL(A.IsRevisionSumYY, '0') = '0' THEN ISNULL(A.OccurDays, 0) + + ISNULL(A.PileDays, 0)
					ELSE ISNULL(A.OccurDays, 0) + ISNULL(X.Revision_OccurDays, 0) + ISNULL(A.PileDays, 0)
			   END AS TotOccurDays,   -- 총발생일수 #bhlee_20190513
			   CASE WHEN ISNULL(A.OccurDays, 0) = 0 THEN ISNULL(A.UseDays, 0) + ISNULL(X.Revision_UseDays, 0)
					ELSE ISNULL(A.UseDays, 0)
			   END AS UseDays,     -- 사용일수
			   CASE WHEN ISNULL(A.IsRevisionSumYY, '0') = '0' THEN ISNULL(A.SumPileDays, 0)    
					ELSE ISNULL(A.SumPileDays, 0) + ISNULL(X.Revision_SumPileDays, 0)
			   END AS SumPileDays, -- 적치일수계
			   CASE WHEN ISNULL(A.IsRevisionSumYY, '0') = '0' THEN (ISNULL(A.PileDays, 0) + ISNULL(A.OccurDays, 0)) - (ISNULL(A.UseDays, 0) + ISNULL(A.SumPileDays, 0)) 
				    ELSE (ISNULL(A.PileDays, 0) + ISNULL(X.Revision_PileDays, 0) + ISNULL(A.OccurDays, 0)   + ISNULL(X.Revision_OccurDays, 0)) -
						 (ISNULL(A.UseDays, 0) + ISNULL(A.SumPileDays, 0) + ISNULL(X.Revision_SumPileDays, 0)) 
			   END AS PayDays, 
			   A.UseFrDate AS UseFrDate,
			   A.UseToDate AS UseToDate,
			   CASE WHEN ISNULL(A.OccurDays, 0) = 0 THEN CASE WHEN ISNULL(A.IsRevisionSumYY, '0') = '0' THEN (ISNULL(A.PileDays, 0) + ISNULL(A.OccurDays, 0)) - (ISNULL(A.UseDays,0) + ISNULL(A.SumPileDays, 0) + ISNULL(X.Revision_UseDays, 0)) 
															  ELSE (ISNULL(A.PileDays, 0) + ISNULL(X.Revision_PileDays, 0) + ISNULL(A.OccurDays, 0)   + ISNULL(X.Revision_OccurDays, 0)) -
																   (ISNULL(A.UseDays, 0)  + ISNULL(A.SumPileDays, 0) + ISNULL(X.Revision_SumPileDays, 0) + ISNULL(X.Revision_UseDays, 0))
														 END
				    ELSE CASE WHEN ISNULL(A.IsRevisionSumYY, '0') = '0' THEN (ISNULL(A.PileDays, 0) + ISNULL(A.OccurDays, 0)) - (ISNULL(A.UseDays,0) + ISNULL(A.SumPileDays, 0)) 
							  ELSE (ISNULL(A.PileDays, 0) + ISNULL(X.Revision_PileDays, 0) + ISNULL(A.OccurDays, 0)   + ISNULL(X.Revision_OccurDays, 0)) -
								   (ISNULL(A.UseDays, 0)  + ISNULL(A.SumPileDays, 0) + ISNULL(X.Revision_SumPileDays, 0))
						 END 
			   END AS BalanceDays,-- 잔여일수
			   A.PayYM          AS PayYM,       -- 실지급월
			   (SELECT PbName FROM _TPRBasPb WITH(NOLOCK) WHERE CompanySeq = @CompanySeq AND PbSeq = A.PbSeq) AS PbName,   -- 지급급상여
			   A.PbSeq          AS PbSeq,       -- 급상여구분
			   A.GnerAmtYyMm    AS GnerAmtYyMm, -- 통상임금기준월
			   A.AddDays        AS AddDays    , -- 추가발생일
			   ISNULL(A.OccurTime   ,0)    AS OccurTime  ,  -- 발생시간
			   ISNULL(A.UseTime     ,0)    AS UseTime    ,  -- 사용시간
			   ISNULL(A.PileTime    ,0)    AS PileTime   ,  -- 이월적치시간
			   ISNULL(A.SumPileTime ,0)    AS SumPileTime,  -- 적치시간
			   (ISNULL(A.PileTime, 0) + ISNULL(A.OccurTime, 0)) - (ISNULL(A.UseTime, 0) + ISNULL(A.SumPileTime, 0)) AS BalanceTime,  -- 잔여시간
			   ISNULL(C.EMPDATE,'')        AS GrpEntDate,   -- 그룹입사일
			   ISNULL(E.BizUnitName,'')    AS BizUnitName,  -- 사업부문
			   ISNULL(F.AccUnitName, '')   AS AccUnitName   -- 회계단위
		  FROM #YYMM AS A 
		  LEFT JOIN _fnAdmEmpOrd(@CompanySeq, '') AS B			    ON A.EmpSeq     = B.EmpSeq
		  LEFT JOIN _TDAEmpDate					  AS C WITH(NOLOCK) ON C.CompanySeq = @CompanySeq 
		  		 								                   AND A.EmpSeq     = C.EmpSeq
		  		 								                   AND C.SMDateType = 3054001			    
		  LEFT JOIN _TDADept				      AS D WITH(NOLOCK) ON D.CompanySeq = @CompanySeq 
		  		 								                   AND B.DeptSeq    = D.DeptSeq 
		  LEFT JOIN _TDAbizunit					  AS E WITH(NOLOCK) ON D.CompanySeq = E.CompanySeq 
		  		 								                   AND D.BizUnit    = E.BizUnit				    
		  LEFT JOIN _TDAAccUnit					  AS F WITH(NOLOCK) ON D.CompanySeq = F.CompanySeq 
																   AND D.AccUnit    = F.AccUnit   
                        
		  LEFT JOIN (SELECT A1.EmpSeq		    AS EmpSeq
						   --,MIN(A1.UseFrDate)   AS Revision_UseFrDate
						   --,MAX(A1.UseToDate)	AS Revision_UseToDate
						   ,SUM(A1.PileDays)    AS Revision_PileDays 
						   ,SUM(A1.OccurDays)   AS Revision_OccurDays
						   --,SUM(A1.UseDays)     AS Revision_UseDays
						   ,SUM(A1.SumPileDays) AS Revision_SumPileDays
						   ,SUM(A1.AddDays)     AS Revision_AddDays
						   ,SUM(A1.UseDays)		AS Revision_UseDays
					   FROM #YYMM		AS A1
					   JOIN _TDAEmpDate AS B1 ON B1.EmpSeq	   = A1.EmpSeq
											 AND B1.SMDateType = 3054007
											 AND B1.EmpDate   >= '20170530'
											 AND B1.CompanySeq = @CompanySeq
					  WHERE RevisionSeq = 1
					  GROUP BY A1.EmpSeq) AS X ON X.EmpSeq = A.EmpSeq
	 	 WHERE (@FromYY    = ''	    OR A.YY  >= @FromYY)
		   AND (@ToYY      = ''     OR A.YY  <= @ToYY  )
		   AND (A.PayYM    = @PayYM OR @PayYM = ''     ) -- #bhlee_20190514
		   AND RevisionSeq = 0 
		 ORDER BY A.YY, B.DeptName, B.EmpName, A.RevisionSeq DESC
	END
RETURN