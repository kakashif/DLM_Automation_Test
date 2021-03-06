USE [SportsDB]
GO
/****** Object:  Table [dbo].[PGA_Fedex_Ranking]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[PGA_Fedex_Ranking](
	[pos] [int] NOT NULL,
	[name] [varchar](128) NOT NULL,
	[points] [varchar](10) NOT NULL,
 CONSTRAINT [PK_PGA_Fedex_Ranking] PRIMARY KEY CLUSTERED 
(
	[pos] ASC,
	[name] ASC,
	[points] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
