USE [SportsDB]
GO
/****** Object:  Table [dbo].[tennis_action_points]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[tennis_action_points](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[sub_period_id] [varchar](100) NULL,
	[sequence_number] [varchar](100) NULL,
	[win_type] [varchar](100) NULL,
 CONSTRAINT [PK__tennis_action_po__42E1EEFE] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
