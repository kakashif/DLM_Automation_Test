USE [SportsDB]
GO
/****** Object:  Table [dbo].[stats]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[stats](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[stat_repository_type] [varchar](100) NULL,
	[stat_repository_id] [int] NOT NULL,
	[stat_holder_type] [varchar](100) NULL,
	[stat_holder_id] [int] NULL,
	[stat_coverage_type] [varchar](100) NULL,
	[stat_coverage_id] [int] NULL,
	[context] [varchar](40) NOT NULL,
	[stat_membership_type] [varchar](40) NULL,
	[stat_membership_id] [int] NULL,
	[scope] [varchar](255) NULL,
 CONSTRAINT [PK__stats__3B40CD36] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
