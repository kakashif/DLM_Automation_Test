USE [SportsDB]
GO
/****** Object:  Table [dbo].[bookmakers]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[bookmakers](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[bookmaker_key] [varchar](100) NULL,
	[publisher_id] [int] NOT NULL,
	[location_id] [int] NULL,
 CONSTRAINT [PK__bookmakers__534D60F1] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
