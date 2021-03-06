USE [SportsDB]
GO
/****** Object:  Table [dbo].[SMG_Suspender_List]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[SMG_Suspender_List](
	[platform] [varchar](100) NOT NULL,
	[sport] [varchar](100) NOT NULL,
	[order] [int] NOT NULL,
	[active] [int] NOT NULL,
 CONSTRAINT [PK_SMG_Suspender_List] PRIMARY KEY CLUSTERED 
(
	[platform] ASC,
	[sport] ASC,
	[order] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
