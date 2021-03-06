USE [SportsDB]
GO
/****** Object:  Table [dbo].[persons]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[persons](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[person_key] [varchar](100) NOT NULL,
	[publisher_id] [int] NOT NULL,
	[gender] [varchar](20) NULL,
	[birth_date] [varchar](30) NULL,
	[death_date] [varchar](30) NULL,
	[birth_location_id] [int] NULL,
	[hometown_location_id] [int] NULL,
	[residence_location_id] [int] NULL,
	[death_location_id] [int] NULL,
	[final_resting_location_id] [int] NULL,
 CONSTRAINT [PK__persons__117F9D94] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
ALTER TABLE [dbo].[persons]  WITH CHECK ADD  CONSTRAINT [FK_persons_final_resting_location_id_locations_id] FOREIGN KEY([final_resting_location_id])
REFERENCES [dbo].[locations] ([id])
GO
ALTER TABLE [dbo].[persons] CHECK CONSTRAINT [FK_persons_final_resting_location_id_locations_id]
GO
