USE [SportsDB]
GO
/****** Object:  Table [dbo].[rankings]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[rankings](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[document_fixture_id] [int] NOT NULL,
	[participant_type] [varchar](100) NOT NULL,
	[participant_id] [int] NOT NULL,
	[issuer] [varchar](100) NULL,
	[ranking_type] [varchar](100) NULL,
	[ranking_value] [varchar](100) NULL,
	[ranking_value_previous] [varchar](100) NULL,
	[date_coverage_type] [varchar](100) NULL,
	[date_coverage_id] [int] NULL,
 CONSTRAINT [PK__rankings__178D7CA5] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
