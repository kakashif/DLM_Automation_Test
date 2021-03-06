USE [SportsDB]
GO
/****** Object:  Table [dbo].[participants_events]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[participants_events](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[participant_type] [varchar](100) NOT NULL,
	[participant_id] [int] NOT NULL,
	[event_id] [int] NOT NULL,
	[alignment] [varchar](100) NULL,
	[score] [varchar](100) NULL,
	[event_outcome] [varchar](100) NULL,
	[rank] [int] NULL,
	[result_effect] [varchar](100) NULL,
	[score_attempts] [int] NULL,
	[sort_order] [varchar](100) NULL,
	[score_type] [varchar](100) NULL,
 CONSTRAINT [PK__participants_eve__1CBC4616] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
