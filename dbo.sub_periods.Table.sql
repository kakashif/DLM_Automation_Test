USE [SportsDB]
GO
/****** Object:  Table [dbo].[sub_periods]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[sub_periods](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[period_id] [int] NOT NULL,
	[sub_period_value] [varchar](100) NULL,
	[score] [varchar](100) NULL,
	[score_attempts] [int] NULL,
 CONSTRAINT [PK__sub_periods__3D2915A8] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
