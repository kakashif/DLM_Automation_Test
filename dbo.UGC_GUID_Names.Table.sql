USE [SportsDB]
GO
/****** Object:  Table [dbo].[UGC_GUID_Names]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[UGC_GUID_Names](
	[first] [varchar](100) NOT NULL,
	[last] [varchar](100) NOT NULL,
	[guid] [varchar](100) NOT NULL,
	[number] [int] NOT NULL,
	[date_time] [datetime] NOT NULL,
	[center] [varchar](100) NULL,
 CONSTRAINT [PK_UGC_GUID_Names] PRIMARY KEY CLUSTERED 
(
	[first] ASC,
	[last] ASC,
	[guid] ASC,
	[number] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
