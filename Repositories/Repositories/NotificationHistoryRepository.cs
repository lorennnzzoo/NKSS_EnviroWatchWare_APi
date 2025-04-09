using Dapper;
using Models.Notification;
using Npgsql;
using Repositories.Interfaces;
using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Repositories
{
    public class NotificationHistoryRepository : INotificationHistoryRepository
    {
        private readonly string _connectionString;
        public NotificationHistoryRepository()
        {
            _connectionString = ConfigurationManager.ConnectionStrings["PostgreSQLConnection"].ConnectionString;
        }
        public IEnumerable<NotificationHistory> GetAllNotifications()
        {
            using( IDbConnection db=new Npgsql.NpgsqlConnection(_connectionString))
            {
                string query = @"SELECT * FROM public.""NotificationHistory""";
                return db.Query<Models.Notification.NotificationHistory>(query).ToList();
            }
        }

        public IEnumerable<NotificationHistory> GetUnreadNotifications()
        {
            using (IDbConnection db = new Npgsql.NpgsqlConnection(_connectionString))
            {
                string query = @"SELECT * FROM public.""NotificationHistory"" WHERE ""IsRead""=False";
                return db.Query<Models.Notification.NotificationHistory>(query).ToList();
            }
        }

        public void ReadNotification(int notificaitonId)
        {
            using (IDbConnection db = new NpgsqlConnection(_connectionString))
            {
                string query = @"UPDATE public.""NotificationHistory"" SET ""IsRead"" = True Where ""Id""=@id";
                db.Execute(query, new { id = notificaitonId });
            }
        }
    }
}
