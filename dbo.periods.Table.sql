USE [SportsDB]
GO
/****** Object:  Table [dbo].[periods]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[periods](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[participant_event_id] [int] NOT NULL,
	[period_value] [varchar](100) NULL,
	[score] [varchar](100) NULL,
	[label] [varchar](100) NULL,
	[score_attempts] [int] NULL,
	[rank] [varchar](100) NULL,
	[sub_score_key] [varchar](100) NULL,
	[sub_score_type] [varchar](100) NULL,
	[sub_score_name] [varchar](100) NULL,
 CONSTRAINT [PK__periods__1EA48E88] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
