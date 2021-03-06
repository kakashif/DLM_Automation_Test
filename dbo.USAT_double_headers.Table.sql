USE [SportsDB]
GO
/****** Object:  Table [dbo].[USAT_double_headers]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[USAT_double_headers](
	[event_id] [int] NOT NULL,
	[event_key] [varchar](100) NULL,
	[event_date_ET] [datetime] NULL,
	[event_status] [varchar](30) NULL,
	[home_id] [int] NULL,
	[away_id] [int] NULL,
	[home_name] [varchar](40) NULL,
	[away_name] [varchar](40) NULL,
	[event_date] [varchar](12) NULL,
 CONSTRAINT [PK_USAT_double_headers] PRIMARY KEY CLUSTERED 
(
	[event_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
