using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Repositories.Helpers
{
    public static class PGSqlHelper
    {
        public static string GetInsertQuery<T>()
        {
            string tableName = GetTableNameFromClass(typeof(T));
            var properties = typeof(T).GetProperties();
            var columnNames = string.Join(", ", properties.Select(p => $"\"{p.Name}\""));
            var parameterNames = string.Join(", ", properties.Select(p => $"@{p.Name}"));
            return $"INSERT INTO public.{tableName} ({columnNames}) VALUES ({parameterNames})";
        }

        public static string GetUpdateQuery<T>()
        {
            string tableName = GetTableNameFromClass(typeof(T));
            var properties = typeof(T).GetProperties().Where(p => p.Name != "Id");
            var setClauses = string.Join(", ", properties.Select(p => $"\"{p.Name}\" = @{p.Name}"));
            return $"UPDATE public.{tableName} SET {setClauses} WHERE \"Id\" = @Id";
        }

        public static string GetTableNameFromClass(Type type)
        {            
            var className = type.Name;            
            return $"\"{className}\"";
        }
    }
    public static class MSSqlHelper
    {
        public static string GetInsertQuery<T>()
        {
            string tableName = GetTableNameFromClass(typeof(T));
            var properties = typeof(T).GetProperties();
            var columnNames = string.Join(", ", properties.Select(p => $"[{p.Name}]"));
            var parameterNames = string.Join(", ", properties.Select(p => $"@{p.Name}"));
            return $"INSERT INTO {tableName} ({columnNames}) VALUES ({parameterNames})";
        }

        public static string GetUpdateQuery<T>()
        {
            string tableName = GetTableNameFromClass(typeof(T));
            var properties = typeof(T).GetProperties().Where(p => p.Name != "Id");
            var setClauses = string.Join(", ", properties.Select(p => $"[{p.Name}] = @{p.Name}"));
            return $"UPDATE {tableName} SET {setClauses} WHERE [Id] = @Id";
        }

        public static string GetTableNameFromClass(Type type)
        {
            return $"[{type.Name}]";
        }
    }
}
