USE [SportsDB]
GO
/****** Object:  Table [dbo].[baseball_action_contact_details]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[baseball_action_contact_details](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[baseball_action_pitch_id] [int] NOT NULL,
	[location] [varchar](100) NULL,
	[strength] [varchar](100) NULL,
	[velocity] [int] NULL,
	[comment] [varchar](512) NULL,
	[trajectory_coordinates] [varchar](100) NULL,
	[trajectory_formula] [varchar](100) NULL,
 CONSTRAINT [PK__baseball_action___3C69FB99] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
