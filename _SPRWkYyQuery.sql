IF EXISTS (SELECT * From sysobjects Where id = object_id('_SPRWkYyQuery') AND sysstat & 0xf = 4)
DROP PROCEDURE _SPRWkYyQuery
GO
/*************************************************************************************************    
 ��    �� - �������� ��ȸ  
 �� �� �� - 
 �� �� �� - �̹�Ȯ 
*************************************************************************************************/   
CREATE PROCEDURE _SPRWkYyQuery
    @xmlDocument    NVARCHAR(MAX),   -- : ȭ���� ������ xml�� ����
    @xmlFlags       INT = 0,         -- : �ش� xml�� Type
    @ServiceSeq     INT = 0,         -- : ���� ��ȣ
    @WorkingTag     NVARCHAR(10)= '',-- : WorkingTag
    @CompanySeq     INT = 1,         -- : ȸ�� ��ȣ
    @LanguageSeq    INT = 1,         -- : ��� ��ȣ
    @UserSeq        INT = 0,         -- : ����� ��ȣ
    @PgmSeq        	INT = 0          -- : ���α׷� ��ȣ

AS
    DECLARE @docHandle       INT,
            @PuSeq           INT,
            @PtSeq           INT,
            @DeptSeq         INT,
            @EmpSeq          INT,
            @FromYY          NCHAR(4),   -- ��ȸ�ⰣFrom
            @ToYY            NCHAR(4),   -- ��ȸ�ⰣTo
            @EntRetType	     INT     ,   -- ����/��������
            @FromYM          NCHAR(6),   -- �߻����From
            @ToYM            NCHAR(6),   -- �߻����To
			@UserEmpSeq      INT			-- UserSeq �������� Empseq ��������
		   ,@EmpYyAmtPbSeq   INT
		   ,@CountFromYY     NCHAR(4)
		   ,@CountToYY       NCHAR(4)
           ,@IsDeptOrg		 NVARCHAR(1) -- �����μ�����
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
	
	-- ���ο���������ȸ ȭ���� �ƴ� ������������ȸ ��ü��ȸ ������ ȭ�鿡�� ��ȸ �ϱ� ���� ���� ���
	SELECT @UserEmpSeq = ISNULL(@EmpSeq,0)
	-- �����̽��� ���� UserSeq �������� EmpSeq ��������
	
	IF @PgmSeq=1637 -- ���ο��� ������ȸ ȭ�鿡���� UserSeq �������� EmpSeq �����ü� �ֵ���..
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
    -- �����߻��� ����ϼ�        
    --===================
    CREATE TABLE #YYMM        
    (   YY              NCHAR(4)    NOT NULL,   -- �⵵
        EmpSeq          INT         NOT NULL,   -- ���
        OccurFrDate     NCHAR(8)        NULL,   -- �߻�������
        OccurToDate     NCHAR(8)        NULL,   -- �߻�������
        OccurDays       NUMERIC(19, 5)  NULL,   -- �߻��ϼ�
        UseDays         DECIMAL(19, 5)  NULL,   -- ����ϼ�        
        UseFrDate       NCHAR(8)        NULL,   -- ��������        
        UseToDate       NCHAR(8)        NULL,   -- ���������        
        PayYM           NCHAR(6)        NULL,   -- ���޿�
        PbSeq           INT             NULL,   -- �޻�����
        PileDays        NUMERIC(19, 5)  NULL,   -- �̿���ġ�ϼ�
        SumPileDays     NUMERIC(19, 5)  NULL,   -- ��ġ�ϼ�
        GnerAmtYyMm     NCHAR(6)        NULL,   -- ����ӱݱ��ؿ�
        AddDays         NUMERIC(19, 5)  NULL,   -- �߰��߻���
        OccurTime       NUMERIC(19, 5)  NULL,   -- �߻��ð�
        UseTime         NUMERIC(19, 5)  NULL,   -- ���ð�
        PileTime        NUMERIC(19, 5)  NULL,   -- �̿���ġ�ð�
        SumPileTime     NUMERIC(19, 5)  NULL,   -- ��ġ�ð�
	    RevisionSeq     INT				NULL,   -- �������� #bhlee_20180815
		RevisionDays    NUMERIC(19, 5)  NULL,   -- ���������ϼ�	 #bhlee_20190513
		TotOccurDays	NUMERIC(19, 5)  NULL,   -- �ѹ߻��ϼ�		 #bhlee_20190513
		IsRevisionSumYY NCHAR(1)		NULL    -- ���������ջ꿬�� #bhlee_20190513
	   ,EntYY			NCHAR(4)		NULL
	    
    )        
	CREATE CLUSTERED INDEX YYMM_index ON #YYMM(EmpSeq)

	--===============================
	-- ���� ���� ����� ���� ��� ���̺�
	--===============================
    CREATE TABLE #Use        
    (   YY          NCHAR(4)        NOT NULL,   -- �⵵
        EmpSeq      INT             NOT NULL,   -- ���
        UseDays     NUMERIC(19, 5)      NULL,   -- ����ϼ�  
        UseTime     NUMERIC(19, 5)      NULL    -- ���ð� 
    )        

	--=================================================================
	-- 2017�� 5�� 30�� ���� �Ի��ڵ��� �ſ� ���� �߻������� �߻��ϼ� ��� ���̺�
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
	-- ����� ���� ����� ���� ��� ���̺�
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
	-- #EmpUseDays ���̺��� �����͸� �����Ͽ� ��� ���̺�
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
	-- #EmpUseDays ���̺��� �����͸� �����Ͽ� ��� ���̺�
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
	
	-- �����߻����ؿ��� 1���� �ƴϸ鼭 ���ؿ��� -1�� ���
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
			   ISNULL(A.BasePileDays, 0) + ISNULL(A.AddPileDays, 0),    -- �⺻��ġ�ϼ� + �߰���ġ�ϼ�
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
		  AND (@IsDeptOrg = '1' OR (@IsDeptOrg <> '1' AND (B.DeptSeq = @DeptSeq OR @DeptSeq = 0)))    -- �μ�
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
			   ISNULL(A.BasePileDays, 0) + ISNULL(A.AddPileDays, 0),    -- �⺻��ġ�ϼ� + �߰���ġ�ϼ�
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
		  AND (@IsDeptOrg = '1' OR (@IsDeptOrg <> '1' AND (B.DeptSeq = @DeptSeq OR @DeptSeq = 0)))    -- �μ�
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
			   ISNULL(A.BasePileDays, 0) + ISNULL(A.AddPileDays, 0),    -- �⺻��ġ�ϼ� + �߰���ġ�ϼ�
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
		  AND (@IsDeptOrg = '1' OR (@IsDeptOrg <> '1' AND (B.DeptSeq = @DeptSeq OR @DeptSeq = 0)))    -- �μ�
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
		IF @IsDeptOrg = '1' -- �����μ� ������ ���
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
				   ISNULL(A.BasePileDays, 0) + ISNULL(A.AddPileDays, 0),    -- �⺻��ġ�ϼ� + �߰���ġ�ϼ�
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
			  AND (@IsDeptOrg = '1' OR (@IsDeptOrg <> '1' AND (B.DeptSeq = @DeptSeq OR @DeptSeq = 0)))    -- �μ�
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
		ELSE -- ���� �μ� �������� ���
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
				   ISNULL(A.BasePileDays, 0) + ISNULL(A.AddPileDays, 0),    -- �⺻��ġ�ϼ� + �߰���ġ�ϼ�
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
			  AND (@IsDeptOrg = '1' OR (@IsDeptOrg <> '1' AND (B.DeptSeq = @DeptSeq OR @DeptSeq = 0)))    -- �μ�
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
											
    IF @IsRevisionSum = '0' -- ���������հ迩�ΰ� '0'�� ��
	BEGIN
		IF @IsDeptOrg = '1' -- �����μ� ������ ���
		BEGIN
			--===============
			-- �������� �����
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
			   AND (@IsDeptOrg = '1' OR (@IsDeptOrg <> '1' AND (Z.DeptSeq = @DeptSeq OR @DeptSeq = 0)))    -- �μ�
			   AND (Z.PuSeq   = @PuSeq OR @PuSeq = 0)        -- 
			   AND (Z.PtSeq   = @PtSeq OR @PtSeq = 0)        -- 
			   AND (@EntRetType = 0 OR (@EntRetType = 3031001 AND Z.RetDate = '') OR (@EntRetType = 3031002 AND Z.RetDate <> ''))
			   AND (@FromYM = '' OR A.YM >= @FromYM)
			   AND (@ToYM = ''   OR A.YM <= @ToYM)
			 GROUP BY LEFT(A.YM, 4), A.EmpSeq
		END
		ELSE -- �����μ� ������ �ƴ� ���
		BEGIN
			--===============
			-- �������� �����
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
			   AND (@IsDeptOrg = '1' OR (@IsDeptOrg <> '1' AND (Z.DeptSeq = @DeptSeq OR @DeptSeq = 0)))    -- �μ�
			   AND (Z.PuSeq   = @PuSeq OR @PuSeq = 0)        -- 
			   AND (Z.PtSeq   = @PtSeq OR @PtSeq = 0)        -- 
			   AND (@EntRetType = 0 OR (@EntRetType = 3031001 AND Z.RetDate = '') OR (@EntRetType = 3031002 AND Z.RetDate <> ''))
			   AND (@FromYM = '' OR A.YM >= @FromYM)
			   AND (@ToYM = ''   OR A.YM <= @ToYM)
			 GROUP BY LEFT(A.YM, 4), A.EmpSeq
		END

		-- �������� ��ġ�ϼ��� �ݿ��ϱ� ���� ������Ʈ�� #bhlee_20190610
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
	 ELSE -- ���������հ迩�ΰ� '1'�� ��	
	 BEGIN
		 --===============
		 -- �������� �����
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
		    AND (@IsDeptOrg = '1' OR (@IsDeptOrg <> '1' AND (Z.DeptSeq = @DeptSeq OR @DeptSeq = 0)))    -- �μ�
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
		    AND (@IsDeptOrg = '1' OR (@IsDeptOrg <> '1' AND (Z.DeptSeq = @DeptSeq OR @DeptSeq = 0)))    -- �μ�
		    AND (Z.PuSeq   = @PuSeq OR @PuSeq = 0)        -- 
		    AND (Z.PtSeq   = @PtSeq OR @PtSeq = 0)        -- 
		    AND (@EntRetType = 0 OR (@EntRetType = 3031001 AND Z.RetDate = '') OR (@EntRetType = 3031002 AND Z.RetDate <> ''))
		    AND (@FromYM = '' OR A.YM >= @FromYM)
		    AND (@ToYM = ''   OR A.YM <= @ToYM)
			AND A.EmpSeq NOT IN (SELECT EmpSeq FROM #YYMM WHERE EmpSeq = A.EmpSeq)
		  GROUP BY LEFT(A.YM, 4), A.EmpSeq
	 END
     
	IF @IsDeptOrg = '1' -- �����μ� ������ ���
	BEGIN
		--============================================= 
		-- [�Ի��ڿ����߻�ó��] ȭ���� ����ϴ� ����� �����
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
			   ISNULL(Z.BasePileDays, 0) + ISNULL(Z.AddPileDays, 0),    -- �⺻��ġ�ϼ� + �߰���ġ�ϼ�
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
		   AND (@IsDeptOrg = '1' OR (@IsDeptOrg <> '1' AND (B.DeptSeq = @DeptSeq OR @DeptSeq = 0)))    -- �μ�
		   AND (B.PuSeq   = @PuSeq OR @PuSeq = 0)        -- 
		   AND (B.PtSeq   = @PtSeq OR @PtSeq = 0)        -- 
		   AND (@EntRetType = 0 OR (@EntRetType = 3031001 AND B.RetDate = '') OR (@EntRetType = 3031002 AND B.RetDate <> ''))
		   AND (@FromYM = '' OR Z.YY + Z.ProcMM >= @FromYM)
		   AND (@ToYM   = '' OR Z.YY + Z.ProcMM <= @ToYM)
		   AND Z.CompanySeq = @CompanySeq
	END
	ELSE -- �����μ� ������ �ƴҰ��
	BEGIN 
		--============================================= 
		-- [�Ի��ڿ����߻�ó��] ȭ���� ����ϴ� ����� �����
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
			   ISNULL(Z.BasePileDays, 0) + ISNULL(Z.AddPileDays, 0),    -- �⺻��ġ�ϼ� + �߰���ġ�ϼ�
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
		   AND (@IsDeptOrg = '1' OR (@IsDeptOrg <> '1' AND (B.DeptSeq = @DeptSeq OR @DeptSeq = 0)))    -- �μ�
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
	  
	DECLARE @Count1         INT      -- ���� ī��Ʈ ��
	       ,@Max1	        INT      -- �ִ� ī��Ʈ ��
		   ,@PresentYear    NCHAR(4) -- ���� ī��Ʈ ����
		   ,@NextYear	    NCHAR(4) -- ���� ī��Ʈ ����
		   ,@PreviousEmpSeq INT		 -- ���� ī��Ʈ ����ڵ�
		   ,@PresentEmpSeq  INT	     -- ���� ī��Ʈ ����ڵ�
		   ,@NextEmpSeq     INT      -- ���� ī��Ʈ ����ڵ�
 
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
	                                          AND C.SMAbsWkSort = 3069002 -- ����

	INSERT INTO #EmpUseDays2(EmpSeq, UseDays, AbsDate, WkItemSeq, Seq)
	SELECT EmpSeq, UseDays, AbsDate, WkItemSeq, ROW_NUMBER()OVER(ORDER BY EmpSeq, AbsDate, WkItemSeq)
	  FROM #EmpUseDays 
	 GROUP BY EmpSeq, AbsDate, UseDays, WkItemSeq
	 ORDER BY EmpSeq, ROW_NUMBER()OVER(ORDER BY EmpSeq, AbsDate, WkItemSeq)												
	

   DECLARE @Count2   INT            -- ���� ī��Ʈ ��
		  ,@Max2	 INT		    -- �ִ� ī��Ʈ ��
		  ,@VarYear  NCHAR(4)	    -- ���� ���� ��
		  ,@MaxYear  NCHAR(4)       -- �ִ� ���� ��
		  ,@UseDays  DECIMAL(19, 5) -- ��������� �� ����
		  ,@UseDays2 DECIMAL(19, 5) -- ��������� �� ����2
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

				-- @UseDays2�� @UseDays�� ���������� ����� ���ڷ� �Ǵ����� �ʾ����� ���� ī���õǴ� ������ڰ� ������ ���� ���Ⱓ�� ���Ե� ��쿡�� ��ī������ �ϱ� ���� �����ϴ� �����̴�.
				IF @UseDays <> -1
				BEGIN
					SELECT @UseDays2 = @UseDays
				END
				
				SELECT @UseDays = CASE WHEN @UseDays = -1 THEN (CASE WHEN EXISTS(SELECT * -- CASE 1 START, CASE 1_Sub START
																				   FROM #temp
																			      WHERE EmpSeq      = A.EmpSeq
																				    AND YY          = @VarYear
																				    AND RevisionSeq = 1) THEN (CASE WHEN (SELECT OccurDays -- CASE 3_Sub START �������뿬�� �߻��ϼ��� ����ϼ��� ���� ��
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
																											        WHEN (SELECT OccurDays -- �������뿬�� �߻��ϼ��� ����ϼ����� ���� ��
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
																												    WHEN (SELECT OccurDays -- �������뿬�� �߻��ϼ��� ����ϼ����� Ŭ ��
																															FROM #temp
																														   WHERE EmpSeq      = A.EmpSeq
																														 	 AND YY		     = @VarYear
																															 AND RevisionSeq = 1) > @UseDays2 THEN (CASE WHEN @UseDays2 + 0.5 = (SELECT OccurDays -- CASE 6_Sub2 START 0.5���� ���� ����ϼ��� �߻��ϼ��� ���� ��	
																																																  FROM #temp
																																																 WHERE EmpSeq      = A.EmpSeq
																																																   AND YY          = @VarYear
																																																   AND RevisionSeq = 1) THEN (CASE WHEN A.UseDays = 0.5 THEN @UseDays2 + A.UseDays -- CASE 7_Sub START ���� ��뿬���� ������ ���
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
																	 WHEN EXISTS(SELECT * -- ȸ�迬�������� ��
																				   FROM #temp
																				  WHERE EmpSeq      = A.EmpSeq
																				    AND YY          = @VarYear
																					AND RevisionSeq = 0) THEN (CASE WHEN (SELECT OccurDays -- CASE 9_Sub START ȸ�迬�� �߻��ϼ��� ����ϼ��� ���� ��
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
																													WHEN (SELECT OccurDays -- ȸ�迬�� �߻��ϼ��� ����ϼ����� ���� ��
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
																													WHEN (SELECT OccurDays -- ȸ�迬�� �߻��ϼ��� ����ϼ����� Ŭ ��
																															FROM #temp
																														   WHERE EmpSeq      = A.EmpSeq
																															 AND YY          = @VarYear
																															 AND RevisionSeq = 0) > @UseDays2 THEN (CASE WHEN @UseDays2 + 0.5 = (SELECT OccurDays -- CASE 12_Sub START 0.5���� ���� ����ϼ��� �߻��ϼ��� ���� ��	
																																																   FROM #temp
																																																  WHERE EmpSeq      = A.EmpSeq
																																																    AND YY          = @VarYear
																																																    AND RevisionSeq = 0) THEN (CASE WHEN A.UseDays = 0.5 THEN @UseDays2 + A.UseDays -- CASE 13_Sub START ���� ��뿬���� ������ ���
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
									   ELSE (CASE WHEN EXISTS(SELECT * -- CASE 2 START �������뿬���� ��
													            FROM #temp
													           WHERE EmpSeq      = A.EmpSeq
													             AND YY          = @VarYear
													             AND RevisionSeq = 1) THEN (CASE WHEN (SELECT OccurDays -- CASE 3 START �������뿬�� �߻��ϼ��� ����ϼ��� ���� ��
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
																							     WHEN (SELECT OccurDays -- �������뿬�� �߻��ϼ��� ����ϼ����� ���� ��
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
																							     WHEN (SELECT OccurDays -- �������뿬�� �߻��ϼ��� ����ϼ����� Ŭ ��
																							             FROM #temp
																									    WHERE EmpSeq      = A.EmpSeq
																									      AND YY		  = @VarYear
																									      AND RevisionSeq = 1) > @UseDays THEN (CASE WHEN @UseDays + 0.5 = (SELECT OccurDays -- CASE 6 START 0.5���� ���� ����ϼ��� �߻��ϼ��� ���� ��	
																																										      FROM #temp
																																										     WHERE EmpSeq      = A.EmpSeq
																																										       AND YY          = @VarYear
																																										       AND RevisionSeq = 1) THEN (CASE WHEN A.UseDays = 0.5 THEN @UseDays + A.UseDays -- CASE 7 START ���� ��뿬���� ������ ���
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
									              WHEN EXISTS(SELECT * -- ȸ�迬�������� ��
													            FROM #temp
															   WHERE EmpSeq     = A.EmpSeq
																AND YY          = @VarYear
																AND RevisionSeq = 0) THEN (CASE WHEN (SELECT OccurDays -- CASE 9 START ȸ�迬�� �߻��ϼ��� ����ϼ��� ���� ��
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
																							    WHEN (SELECT OccurDays -- ȸ�迬�� �߻��ϼ��� ����ϼ����� ���� ��
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
																							    WHEN (SELECT OccurDays -- ȸ�迬�� �߻��ϼ��� ����ϼ����� Ŭ ��
																									    FROM #temp
																									   WHERE EmpSeq      = A.EmpSeq
																									     AND YY          = @VarYear
																									     AND RevisionSeq = 0) > @UseDays THEN (CASE WHEN @UseDays + 0.5 = (SELECT OccurDays -- CASE 12 START 0.5���� ���� ����ϼ��� �߻��ϼ��� ���� ��	
																																										     FROM #temp
																																										    WHERE EmpSeq      = A.EmpSeq
																																											  AND YY          = @VarYear
																																											  AND RevisionSeq = 0) THEN (CASE WHEN A.UseDays = 0.5 THEN @UseDays + A.UseDays -- CASE 13 START ���� ��뿬���� ������ ���
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

			    IF @UseDays <> -1 -- �ſ��߻������� ���� ���ڸ� ��´�.
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
			

				-- ���� ī��Ʈ ����ڵ�� ���� ī��Ʈ ����ڵ尡 ��ġ���� �ʴ� ��� ����� ���� 0���� �ʱ�ȭ
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
    -- �������        
    --================================================================================================================================
	
	INSERT INTO #Use
        (YY, EmpSeq, UseDays, UseTime)         
	
	-- 2017�� 05�� 30�� ���� �Ի���
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
                                                    AND C.SMAbsWkSort = 3069002 -- ����
		   INNER JOIN _TDAEmpDate  AS D WITH(NOLOCK)ON D.CompanySeq = @CompanySeq
												   AND D.EmpSeq		= A.EmpSeq
												   AND D.SMDateType = 3054007
	 WHERE B.AbsDate NOT IN(SELECT AbsDate FROM #InEmpUseDays WHERE EmpSeq = A.EmpSeq AND UseDate = B.AbsDate) -- �ſ��߻������� ���� ���ڴ� ���� #bhlee_20180815
	   AND D.EmpDate >= '20170530'
	   AND A.RevisionSeq = 0
     GROUP BY A.YY, A.EmpSeq

	 UNION ALL

	-- 2017�� 05�� 30�� ���� �Ի���
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
                                                    AND C.SMAbsWkSort = 3069002 -- ����
		   INNER JOIN _TDAEmpDate  AS D WITH(NOLOCK)ON D.CompanySeq = @CompanySeq
												   AND D.EmpSeq		= A.EmpSeq
												   AND D.SMDateType = 3054007
	 WHERE D.EmpDate < '20170530'
     GROUP BY A.YY, A.EmpSeq        
	
    --================================================================================================================================
    -- ����ϼ� update        
    --================================================================================================================================
    -- ȸ����� ���� ����� �� ������Ʈ
    UPDATE #YYMM         
       SET UseDays = ISNULL(B.UseDays, 0), 
           UseTime = ISNULL(B.UseTime, 0)
      FROM #YYMM AS A
           INNER JOIN #Use AS B ON A.YY = B.YY 
                               AND A.EmpSeq = B.EmpSeq
	 WHERE A.RevisionSeq = 0
	  
	-- �ſ��߻����� ����� �� ������Ʈ #bhlee_20180815
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
	IF @IsRevisionSum = '0' -- ���������հ迩�ΰ� '0'�� ���
	BEGIN
		IF @PgmSeq = 1637 -- #bhlee_20180816 (���ο���������ȸ �а�)
		BEGIN
			--================================================================================================================================
			-- ��������
			--================================================================================================================================
			SELECT MAX(A.YY)         AS YY,          -- ���س⵵
				   '0'				 AS IsRevision, -- �������뿬������ #bhlee_20180815
				   MAX(B.EmpName)    AS EmpName,     -- ����
				   MAX(A.EmpSeq)     AS EmpSeq,      -- ����ڵ�
				   MAX(B.EmpID)      AS EmpID,       -- ���
				   MAX(B.DeptName)   AS DeptName,    -- �ҼӺμ�
				   MAX(B.UMJpName)   AS UMJpName,    -- ����
				   MAX(B.UMPgName)   AS UMPgName,    -- ����
				   MAX(B.UMJoName)   AS UMJoName,    -- ����
				   MAX(B.PuName)     AS PuName,      -- �޿��۾���
				   MAX(B.PtName)     AS PtName,      -- �޿����¸�
				   MAX(B.DeptSeq)    AS DeptSeq,     -- �ҼӺμ��ڵ�
				   MAX(B.PuSeq)      AS PuSeq,       -- �޿��۾����ڵ�
				   MAX(B.PtSeq)      AS PtSeq,       -- �޿������Ϸù�ȣ
				   MAX(B.EntDate)    AS EntDate,     -- �Ի���
				   MAX(B.RetDate)    AS RetireDate,  -- ����� 
				   (SELECT EmpDate FROM _TDAEmpDate WITH(NOLOCK) WHERE CompanySeq = @CompanySeq AND EmpSeq = A.EmpSeq AND SMDateType = 3054007) AS EmpDate,    -- �������
				   MIN(A.OccurFrDate)    AS OccurFrDate, -- �߻����ؽ�����
				   MAX(A.OccurToDate)    AS OccurToDate, -- �߻�����������
				   ISNULL(SUM(A.PileDays), 0) AS PileDays,-- �̿���ġ�ϼ�
				   ISNULL(SUM(A.OccurDays), 0) AS OccurDays,   -- �߻��ϼ�
				   ISNULL(SUM(A.UseDays), 0)        AS UseDays,     -- ����ϼ�
				   ISNULL(SUM(A.SumPileDays), 0)    AS SumPileDays, -- ��ġ�ϼ���
				   (ISNULL(SUM(A.PileDays), 0) + ISNULL(SUM(A.OccurDays), 0)) - (ISNULL(SUM(A.UseDays), 0) + ISNULL(SUM(A.SumPileDays), 0) ) AS PayDays,-- 
				   MIN(A.UseFrDate)      AS UseFrDate,   -- ��������
				   MAX(A.UseToDate)      AS UseToDate,   -- ���������
				   (ISNULL(SUM(A.PileDays), 0) + ISNULL(SUM(A.OccurDays), 0)) - (ISNULL(SUM(A.UseDays),0) + ISNULL(SUM(A.SumPileDays), 0)) AS BalanceDays,-- �ܿ��ϼ�
				   ''          AS PayYM,       -- �����޿�
				   '' AS PbName,   -- ���ޱ޻�
				   0          AS PbSeq,       -- �޻󿩱���
				   ''    AS GnerAmtYyMm, -- ����ӱݱ��ؿ�
				   ISNULL(SUM(A.AddDays), 0)        AS AddDays    , -- �߰��߻���
				   0    AS OccurTime  ,  -- �߻��ð�
				   0    AS UseTime    ,  -- ���ð�
				   0    AS PileTime   ,  -- �̿���ġ�ð�
				   0    AS SumPileTime,  -- ��ġ�ð�
				   0 AS BalanceTime,  -- �ܿ��ð�
				   ISNULL(MAX(C.EmpDate),'')        AS GrpEntDate,   -- �׷��Ի���
				   ISNULL(MAX(E.BizUnitName),'')    AS BizUnitName,  -- ����ι�
				   ISNULL(MAX(F.AccUnitName), '')   AS AccUnitName   -- ȸ�����    
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
			-- ��������
			--================================================================================================================================
			SELECT A.YY         AS YY,          -- ���س⵵
				   CONVERT(NCHAR(1), A.RevisionSeq) AS IsRevision, -- �������뿬������ #bhlee_20180815
				   B.EmpName    AS EmpName,     -- ����
				   A.EmpSeq     AS EmpSeq,      -- ����ڵ�
				   B.EmpID      AS EmpID,       -- ���
				   B.DeptName   AS DeptName,    -- �ҼӺμ�
				   B.UMJpName   AS UMJpName,    -- ����
				   B.UMPgName   AS UMPgName,    -- ����
				   B.UMJoName   AS UMJoName,    -- ����
				   B.PuName     AS PuName,      -- �޿��۾���
				   B.PtName     AS PtName,      -- �޿����¸�
				   B.DeptSeq    AS DeptSeq,     -- �ҼӺμ��ڵ�
				   B.PuSeq      AS PuSeq,       -- �޿��۾����ڵ�
				   B.PtSeq      AS PtSeq,       -- �޿������Ϸù�ȣ
				   B.EntDate    AS EntDate,     -- �Ի���
				   B.RetDate    AS RetireDate,  -- ����� 
				   (SELECT EmpDate FROM _TDAEmpDate WITH(NOLOCK) WHERE CompanySeq = @CompanySeq AND EmpSeq = A.EmpSeq AND SMDateType = 3054007) AS EmpDate,    -- �������
				   A.OccurFrDate    AS OccurFrDate, -- �߻����ؽ�����
				   A.OccurToDate    AS OccurToDate, -- �߻�����������
				   ISNULL(A.PileDays, 0) AS PileDays,-- �̿���ġ�ϼ�
				   ISNULL(A.OccurDays, 0) AS OccurDays,   -- �߻��ϼ�
				   A.UseDays        AS UseDays,     -- ����ϼ�
				   A.SumPileDays    AS SumPileDays, -- ��ġ�ϼ���
				   (ISNULL(A.PileDays, 0) + ISNULL(A.OccurDays, 0)) - (ISNULL(A.UseDays, 0) + ISNULL(A.SumPileDays, 0) ) AS PayDays,-- 
				   A.UseFrDate      AS UseFrDate,   -- ��������
				   A.UseToDate      AS UseToDate,   -- ���������
				   (ISNULL(A.PileDays, 0) + ISNULL(A.OccurDays, 0)) - (ISNULL(A.UseDays,0) + ISNULL(A.SumPileDays, 0)) AS BalanceDays,-- �ܿ��ϼ�
				   A.PayYM          AS PayYM,       -- �����޿�
				   (SELECT PbName FROM _TPRBasPb WITH(NOLOCK) WHERE CompanySeq = @CompanySeq AND PbSeq = A.PbSeq) AS PbName,   -- ���ޱ޻�
				   A.PbSeq          AS PbSeq,       -- �޻󿩱���
				   A.GnerAmtYyMm    AS GnerAmtYyMm, -- ����ӱݱ��ؿ�
				   A.AddDays        AS AddDays    , -- �߰��߻���
				   ISNULL(A.OccurTime   ,0)    AS OccurTime  ,  -- �߻��ð�
				   ISNULL(A.UseTime     ,0)    AS UseTime    ,  -- ���ð�
				   ISNULL(A.PileTime    ,0)    AS PileTime   ,  -- �̿���ġ�ð�
				   ISNULL(A.SumPileTime ,0)    AS SumPileTime,  -- ��ġ�ð�
				   (ISNULL(A.PileTime, 0) + ISNULL(A.OccurTime, 0)) - (ISNULL(A.UseTime, 0) + ISNULL(A.SumPileTime, 0)) AS BalanceTime,  -- �ܿ��ð�
				   ISNULL(C.EMPDATE,'')        AS GrpEntDate,   -- �׷��Ի���
				   ISNULL(E.BizUnitName,'')    AS BizUnitName,  -- ����ι�
				   ISNULL(F.AccUnitName, '')   AS AccUnitName   -- ȸ�����      
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
    ELSE -- ���������հ迩�ΰ� '1'�� ���
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

	    -- �����Ի�� ���������ۿ� �������� ���� ��쿡�� �߻��ϼ� 0���� ���������͸� ���Ƿ� ����.
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

		SELECT A.YY         AS YY,          -- ���س⵵
			   CASE WHEN ISNULL(A.IsRevisionSumYY, '0') = '0' THEN '0'	
					ELSE '1'	
			   END	        AS IsRevision, -- �������뿬������ #bhlee_20180815
			   B.EmpName    AS EmpName,     -- ����
			   A.EmpSeq     AS EmpSeq,      -- ����ڵ�
			   B.EmpID      AS EmpID,       -- ���
			   B.DeptName   AS DeptName,    -- �ҼӺμ�
			   B.UMJpName   AS UMJpName,    -- ����
			   B.UMPgName   AS UMPgName,    -- ����
			   B.UMJoName   AS UMJoName,    -- ����
			   B.PuName     AS PuName,      -- �޿��۾���
			   B.PtName     AS PtName,      -- �޿����¸�
			   B.DeptSeq    AS DeptSeq,     -- �ҼӺμ��ڵ�
			   B.PuSeq      AS PuSeq,       -- �޿��۾����ڵ�
			   B.PtSeq      AS PtSeq,       -- �޿������Ϸù�ȣ
			   B.EntDate    AS EntDate,     -- �Ի���
			   B.RetDate    AS RetireDate,  -- ����� 
			   (SELECT EmpDate FROM _TDAEmpDate WITH(NOLOCK) WHERE CompanySeq = @CompanySeq AND EmpSeq = A.EmpSeq AND SMDateType = 3054007) AS EmpDate,    -- �������
			   A.OccurFrDate		  AS OccurFrDate, -- �߻����ؽ�����
			   A.OccurToDate          AS OccurToDate, -- �߻�����������
			   CASE WHEN ISNULL(A.IsRevisionSumYY, '0') = '0' THEN ISNULL(A.PileDays, 0)
					ELSE ISNULL(A.PileDays, 0) + ISNULL(X.Revision_PileDays, 0) 
			   END AS PileDays,    -- �̿���ġ�ϼ�
			   CASE WHEN ISNULL(A.IsRevisionSumYY, '0') = '0' THEN 0
				    ELSE ISNULL(X.Revision_OccurDays, 0)   
			   END AS RevisionDays, -- ���������ϼ� #bhlee_20190513
			   ISNULL(A.OccurDays, 0) AS OccurDays,	   -- �߻��ϼ� 
			   CASE WHEN ISNULL(A.IsRevisionSumYY, '0') = '0' THEN ISNULL(A.OccurDays, 0) + + ISNULL(A.PileDays, 0)
					ELSE ISNULL(A.OccurDays, 0) + ISNULL(X.Revision_OccurDays, 0) + ISNULL(A.PileDays, 0)
			   END AS TotOccurDays,   -- �ѹ߻��ϼ� #bhlee_20190513
			   CASE WHEN ISNULL(A.OccurDays, 0) = 0 THEN ISNULL(A.UseDays, 0) + ISNULL(X.Revision_UseDays, 0)
					ELSE ISNULL(A.UseDays, 0)
			   END AS UseDays,     -- ����ϼ�
			   CASE WHEN ISNULL(A.IsRevisionSumYY, '0') = '0' THEN ISNULL(A.SumPileDays, 0)    
					ELSE ISNULL(A.SumPileDays, 0) + ISNULL(X.Revision_SumPileDays, 0)
			   END AS SumPileDays, -- ��ġ�ϼ���
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
			   END AS BalanceDays,-- �ܿ��ϼ�
			   A.PayYM          AS PayYM,       -- �����޿�
			   (SELECT PbName FROM _TPRBasPb WITH(NOLOCK) WHERE CompanySeq = @CompanySeq AND PbSeq = A.PbSeq) AS PbName,   -- ���ޱ޻�
			   A.PbSeq          AS PbSeq,       -- �޻󿩱���
			   A.GnerAmtYyMm    AS GnerAmtYyMm, -- ����ӱݱ��ؿ�
			   A.AddDays        AS AddDays    , -- �߰��߻���
			   ISNULL(A.OccurTime   ,0)    AS OccurTime  ,  -- �߻��ð�
			   ISNULL(A.UseTime     ,0)    AS UseTime    ,  -- ���ð�
			   ISNULL(A.PileTime    ,0)    AS PileTime   ,  -- �̿���ġ�ð�
			   ISNULL(A.SumPileTime ,0)    AS SumPileTime,  -- ��ġ�ð�
			   (ISNULL(A.PileTime, 0) + ISNULL(A.OccurTime, 0)) - (ISNULL(A.UseTime, 0) + ISNULL(A.SumPileTime, 0)) AS BalanceTime,  -- �ܿ��ð�
			   ISNULL(C.EMPDATE,'')        AS GrpEntDate,   -- �׷��Ի���
			   ISNULL(E.BizUnitName,'')    AS BizUnitName,  -- ����ι�
			   ISNULL(F.AccUnitName, '')   AS AccUnitName   -- ȸ�����
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