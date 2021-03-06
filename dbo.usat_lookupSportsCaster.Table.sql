USE [SportsDB]
GO
/****** Object:  Table [dbo].[usat_lookupSportsCaster]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[usat_lookupSportsCaster](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[sportscaster_url] [varchar](max) NOT NULL,
	[xsl] [varchar](150) NOT NULL,
	[page_url] [varchar](150) NOT NULL,
	[page_desc] [varchar](100) NOT NULL,
	[league_keys] [varchar](100) NULL,
 CONSTRAINT [PK_usat_lookupSportsCaster_1] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
