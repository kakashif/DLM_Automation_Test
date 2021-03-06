USE [SportsDB]
GO
/****** Object:  Table [dbo].[standing_subgroups]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[standing_subgroups](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[standing_id] [int] NOT NULL,
	[affiliation_id] [int] NOT NULL,
	[alignment_scope] [varchar](100) NULL,
	[competition_scope] [varchar](100) NULL,
	[competition_scope_id] [varchar](100) NULL,
	[duration_scope] [varchar](100) NULL,
	[scoping_label] [varchar](100) NULL,
	[site_scope] [varchar](100) NULL,
 CONSTRAINT [PK__standing_subgrou__18EBB532] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
