USE [SportsDB]
GO
/****** Object:  Table [dbo].[event_states]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[event_states](
	[id] [int] NOT NULL,
	[event_id] [int] NOT NULL,
	[current_state] [int] NULL,
	[sequence_number] [int] NULL,
	[period_value] [varchar](100) NULL,
	[period_time_elapsed] [varchar](100) NULL,
	[period_time_remaining] [varchar](100) NULL,
	[minutes_elapsed] [varchar](100) NULL,
	[period_minutes_elapsed] [varchar](100) NULL,
	[context] [varchar](40) NULL,
	[document_id] [int] NULL,
 CONSTRAINT [PK_event_states] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
