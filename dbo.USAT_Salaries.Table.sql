USE [SportsDB]
GO
/****** Object:  Table [dbo].[USAT_Salaries]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[USAT_Salaries](
	[id] [int] IDENTITY(10000001,1) NOT FOR REPLICATION NOT NULL,
	[person_key] [varchar](100) NOT NULL,
	[team_key] [varchar](100) NOT NULL,
	[season_key] [int] NOT NULL,
	[position_id] [int] NULL,
	[salary] [money] NOT NULL,
	[contract_years] [tinyint] NULL,
	[contract_amt] [money] NULL,
	[sign_date] [smalldatetime] NULL,
	[base_salary] [money] NULL,
	[sign_bonus] [money] NULL,
	[report_bonus] [money] NULL,
	[roster_bonus] [money] NULL,
	[workout_bonus] [money] NULL,
	[LTBE] [money] NULL,
	[other_bonus] [money] NULL,
	[cap_value] [money] NULL,
	[notes] [varchar](500) NULL,
	[status] [varchar](200) NULL,
	[free_agency] [varchar](200) NULL,
 CONSTRAINT [PK_USAT_Salaries] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
