USE [SportsDB]
GO
/****** Object:  Table [dbo].[water_polo_foul_stats]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[water_polo_foul_stats](
	[id] [int] NOT NULL,
	[center_forward_exclusions] [int] NULL,
	[field_exclusions] [int] NULL,
	[five_meter_penalties] [int] NULL,
	[substitution_exclusions] [int] NULL,
 CONSTRAINT [PK_water_polo_foul_stats] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
