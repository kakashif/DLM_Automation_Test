USE [SportsDB]
GO
/****** Object:  Table [dbo].[injury_phases]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[injury_phases](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[person_id] [int] NOT NULL,
	[injury_status] [varchar](100) NULL,
	[injury_type] [varchar](100) NULL,
	[injury_comment] [varchar](100) NULL,
	[disabled_list] [varchar](100) NULL,
	[start_date_time] [datetime] NULL,
	[end_date_time] [datetime] NULL,
	[season_id] [int] NULL,
	[phase_type] [varchar](100) NULL,
	[injury_side] [varchar](100) NULL,
 CONSTRAINT [PK__injury_phases__05D8E0BE] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
