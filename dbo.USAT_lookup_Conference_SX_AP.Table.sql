USE [SportsDB]
GO
/****** Object:  Table [dbo].[USAT_lookup_Conference_SX_AP]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[USAT_lookup_Conference_SX_AP](
	[ID] [nvarchar](10) NOT NULL,
	[Name] [nvarchar](250) NOT NULL,
	[League] [nvarchar](10) NOT NULL,
	[LongName] [nvarchar](500) NULL,
	[MetaDescription] [nvarchar](500) NULL,
	[MetaKeywords] [nvarchar](500) NULL,
	[URL] [nvarchar](500) NOT NULL,
	[Active] [bit] NULL,
	[NavigationPath] [nvarchar](500) NOT NULL,
	[StandingPath] [nvarchar](500) NOT NULL,
	[Owner_Id] [bigint] NULL,
	[TSN_Short_Name] [nvarchar](100) NULL,
	[affiliation_key] [varchar](100) NULL,
 CONSTRAINT [PK_USAT_lookup_Conference_SX_AP] PRIMARY KEY CLUSTERED 
(
	[ID] ASC,
	[League] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
