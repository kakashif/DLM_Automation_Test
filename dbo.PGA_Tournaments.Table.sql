USE [SportsDB]
GO
/****** Object:  Table [dbo].[PGA_Tournaments]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[PGA_Tournaments](
	[id] [int] NOT NULL,
	[code] [varchar](2) NOT NULL,
	[cur_rnd] [varchar](10) NULL,
	[loc] [varchar](200) NULL,
	[local_city] [varchar](100) NULL,
	[name] [varchar](200) NULL,
	[loc_state] [varchar](100) NULL,
	[format] [varchar](50) NULL,
	[fedex] [varchar](10) NULL,
 CONSTRAINT [PK_PGA_Tournaments] PRIMARY KEY CLUSTERED 
(
	[id] ASC,
	[code] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
