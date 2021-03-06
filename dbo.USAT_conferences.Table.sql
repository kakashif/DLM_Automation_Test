USE [SportsDB]
GO
/****** Object:  Table [dbo].[USAT_conferences]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[USAT_conferences](
	[affiliation_id] [int] NOT NULL,
	[conference_name] [varchar](255) NULL,
 CONSTRAINT [PK__USAT_conferences__5A6F5FCC] PRIMARY KEY CLUSTERED 
(
	[affiliation_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
