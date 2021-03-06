USE [SportsDB]
GO
/****** Object:  Table [dbo].[soccer_foul_stats]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[soccer_foul_stats](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[fouls_suffered] [varchar](100) NULL,
	[fouls_commited] [varchar](100) NULL,
	[cautions_total] [varchar](100) NULL,
	[cautions_pending] [varchar](100) NULL,
	[caution_points_total] [varchar](100) NULL,
	[caution_points_pending] [varchar](100) NULL,
	[ejections_total] [varchar](100) NULL,
 CONSTRAINT [PK__soccer_foul_stat__37703C52] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
