USE [SportsDB]
GO
/****** Object:  Table [dbo].[affiliations]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[affiliations](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[affiliation_key] [varchar](100) NOT NULL,
	[affiliation_type] [varchar](100) NULL,
	[publisher_id] [int] NOT NULL,
 CONSTRAINT [PK__affiliations__023D5A04] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
