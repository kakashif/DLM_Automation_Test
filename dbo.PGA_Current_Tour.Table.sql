USE [SportsDB]
GO
/****** Object:  Table [dbo].[PGA_Current_Tour]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[PGA_Current_Tour](
	[tour_code] [varchar](2) NOT NULL,
	[tour_id] [int] NULL,
	[format] [varchar](50) NULL,
	[fedex] [varchar](10) NULL,
 CONSTRAINT [PK_PGA_Current_Tour] PRIMARY KEY CLUSTERED 
(
	[tour_code] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
