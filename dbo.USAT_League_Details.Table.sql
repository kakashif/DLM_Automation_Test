USE [SportsDB]
GO
/****** Object:  Table [dbo].[USAT_League_Details]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[USAT_League_Details](
	[league_key] [varchar](100) NOT NULL,
	[conference_key] [varchar](100) NOT NULL,
	[division_key] [varchar](100) NOT NULL,
	[conference_name] [varchar](100) NULL,
	[conference_display] [varchar](100) NULL,
	[conference_order] [int] NULL,
	[division_name] [varchar](100) NULL,
	[division_display] [varchar](100) NULL,
	[division_order] [int] NULL,
 CONSTRAINT [PK_USAT_League_Details] PRIMARY KEY CLUSTERED 
(
	[league_key] ASC,
	[conference_key] ASC,
	[division_key] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
