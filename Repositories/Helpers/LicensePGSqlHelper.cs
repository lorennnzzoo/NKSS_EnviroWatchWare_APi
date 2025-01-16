using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Repositories.Helpers
{
    public static class LicensePGSqlHelper
    {
        public static string GetUpdateQuery<T>()
        {
            string tableName = PGSqlHelper.GetTableNameFromClass(typeof(T));
            var properties = typeof(T).GetProperties().Where(p => p.Name != "Id");
            var setClauses = string.Join(", ", properties.Select(p => $"\"{p.Name}\" = @{p.Name}"));
            return $"UPDATE public.{tableName} SET {setClauses} WHERE \"LicenseType\" = @LicenseType";
        }
    }
}
